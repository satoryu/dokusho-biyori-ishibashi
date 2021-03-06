Document.ready? do
  if Element.find('body.keywords').size > 0
    def append_keyword(event)
      form = event.current_target.parents.map{|parent| parent if parent.has_class?('new_keyword')}.compact.first
      # 通信中はボタンをdisableにする
      button = form.find('.mdl-button')
      button.add_class('disabled')

      HTTP.post(form['action'], :payload => form.serialize) do |response|
        # 通信終了したのでボタンを元に戻す
        button.remove_class('disabled')

        if response.ok?
          data = response.json
          # リストにキーワード追加
          list_item = Element.parse(data['list_item'])
          form.parent.find('.keywords').append(list_item)
          # 削除イベント
          list_item.find('.mdl-button.delete').on('click') do |event|
            delete_keyword(event)
            false
          end
          # フォームクリア
          form.find('input[type="text"]').value = ''
          button.add_class('disabled')
        else
          alert('追加に失敗しました。')
        end
      end
    end

    def delete_keyword(event)
      keyword_id = event.current_target.attr('data-id')
      confirm('このキーワードを削除します') do
        HTTP.delete("/keywords/#{keyword_id}") do |response|
          if response.ok?
            # リストから削除
            Element.find("li[data-id='#{keyword_id}']").fade_out
          else
            alert('削除に失敗しました。')
          end
        end
      end
    end

    # 既存キーワード一覧にイベントハンドラ設定
    Element.find('ul.keywords>li .mdl-button.delete').on('click') do |event|
      delete_keyword(event)
      false
    end

    # 追加ボタンにイベントハンドラ設定
    Element.find('form.new_keyword .mdl-button').on('click') do |event|
      append_keyword(event) unless event.current_target.has_class?('disabled')
      false
    end

    # textfieldでエンター
    Element.find('input[name="keyword[value]"]').on('keypress') do |event|
      if event.which == 13
        append_keyword(event) unless event.current_target.has_class?('disabled')
        false
      end
    end

    # 追加ボタンはキーワードが入力され、重複していない場合のみenable
    Element.find('input[name="keyword[value]"]').on('keyup') do |event|
      unless event.which == 13
        text_field = event.current_target
        form = text_field.parent.parent
        button = form.find('.mdl-button')
        keywords = form.parent.find('.keywords .value').map{|e| e.text.gsub(/\n/, '').strip }
        if text_field.value.to_s.strip == '' or keywords.include?(text_field.value)
          button.add_class('disabled')
          event.current_target.add_class('disabled')
        else
          button.remove_class('disabled')
          event.current_target.remove_class('disabled')
        end
      end

      false
    end

    # ユーザ設定
    Element.find('#user-settings input[type="checkbox"]').on('change') do |event|
      form = Element.find('#user-settings')
      HTTP.post(form['action'], :payload => form.serialize) do |response|
        if response.ok?
          # do nothing
        else
          alert('設定の変更に失敗しました。')
        end
      end
    end

    Element.find('#user_private').on('change') do |event|
      # 非公開の場合のみランダムURLのチェックボックスを有効にする
      if Element.find('#user_private').is(':checked')
        Element.find('#random-url-container').remove_class('disabled')
        Element.find('#user_random_url').remove_attr('disabled')
      else
        Element.find('#random-url-container').add_class('disabled')
        Element.find('#user_random_url')['disabled'] = 'disabled'
      end
    end
  end
end
