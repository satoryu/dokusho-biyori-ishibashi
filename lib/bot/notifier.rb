module DokushoBiyoriBot
  class Notifier
    def initialize(config, logger = Logger.new(STDOUT))
      @rest = Twitter::REST::Client.new do |c|
        c.consumer_key = config[:consumer][:key]
        c.consumer_secret = config[:consumer][:secret]
        c.access_token = config[:access][:key]
        c.access_token_secret = config[:access][:secret]
      end

      # 自分が誰なのか
      @current_user = @rest.user
      @followers = @rest.follower_ids.to_h[:ids]

      # 商品ページ
      @product_page_url = config[:product_page_url]
    end

    # フォローを解除したユーザの要求を削除する
    def clean_unfollower
      BotKeyword.all.select{|bk| !@followers.include?(bk.twitter_user_id.to_i) }.
        each do |bot_keyword|
          BotKeyword.transaction do
            bot_keyword.destroy
            user_keyword = bot_keyword.user_keyword
            user_keyword.destroy if user_keyword.bot_keywords.blank?
          end
        end
    end

    # Twitterユーザごとに要求と通知対象をまとめる
    def notify_targets
      bot_keywords = BotKeyword.all.group_by{|bk| bk.twitter_user_id }
      users = @rest.users(bot_keywords.keys.map(&:to_i)).map{|u| [u.id, u] }.to_h
      # {Twitter::User => {BotKeyword => [KeywordProduct]}}
      bot_keywords.map{|u, bk| [users[u.to_i], bk] }.to_h.
        map{|user, bot_keywords| [user, bot_keywords.map{|bk| [bk, bk.keyword_products_to_notify] }.to_h ] }.to_h.
        map{|user, notifications| [user, notifications.reject{|k, v| v.blank? }] }.reject{|e| e.last.blank? }.to_h
    end

    # 返信実行
    def notify(user, notifications)
      message, reply_to = create_message(user, notifications)
      sleep 2 # 一日1000tweet数の制限を超えないように
      tweet = @rest.update(message, :in_reply_to_status_id => reply_to.to_i)

      # 送信済みとマーク
      notifications.each do |bot_keyword, keyword_products|
        keyword_products.each {|kp| bot_keyword.notified(kp) }
        bot_keyword.save
      end
    end

    # 返信文生成
    def create_message(user, notifications)
      @user = user
      if notifications.keys.find{|bk| bk.notify_at.present? }.present?
        # 当日通知を優先
        template = 'current'
        # 本日に一番近いものを選択
        @bot_keyword = notifications.keys.
          reject{|bk| bk.notify_at.nil? }.
          sort{|a, b| a.notify_at <=> b.notify_at }.first
        @product = notifications[@bot_keyword].first.product
      else
        # 情報通知のみ
        template = 'info'
        # 発売日が一番早いものを優先
        @product = notifications.values.flatten.map(&:product).
          sort{|a, b| a.release_date <=> b.release_date }.first
        @bot_keyword = notifications.find{|k, v| v.find{|kp| kp.product_id == @product.id }.present? }.first
      end

      @other_products = notifications.values.flatten.map(&:product).
        reject{|p| p == @product }.
        sort{|a, b| a.release_date <=> b.release_date }

      @product_page = "#{@product_page_url}/#{@product.ean}"
      if @other_products.present?
        @product_page += '?' +
          @other_products.map(&:ean).map{|e| "ean[]=#{e}" }.join('&')
      end

      return render(template), @bot_keyword.tweet_id
    end

    private
    def render(template)
      t = ERB.new(open("lib/bot/views/notifier/#{template}.text.erb").read)
      (0..@other_products.size).
        map{|i| @include_others_size = i; t.result(binding) }.
        map{|r| r.gsub(/^ +/, '').gsub("\n", '') }.
        sort{|a, b| b.size <=> a.size }.
        reject{|r| r.gsub(@product_page || 'a' * 24, 'a' * 24).size > 140 }.
        first
    end
  end
end
