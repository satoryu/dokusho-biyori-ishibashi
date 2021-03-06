class User < ActiveRecord::Base
  has_many :user_keywords
  has_many :user_products

  before_save :manage_key

  # tagsテーブルを更新する
  def update_tags(added, removed)
    # マイグレーション時の互換処理
    if tags.is_a?(String)
      current = JSON.parse(tags)
    else
      current = tags
    end

    added.each do |tag|
      if current[tag].present?
        current[tag] += 1
      else
        current[tag] = 1
      end
    end

    removed.each do |tag|
      if current[tag].present?
        if current[tag] == 1
          current.delete(tag)
        else
          current[tag] -= 1
        end
      end
    end

    self.tags = current.to_json
    if tags.is_a?(String)
    else
      self.tags = current
    end
  end

  def search_user_products(keyword)
    UserProduct.search(:text => keyword, :user_id => self.id)
  end

  private
  def manage_key
    if self.changes.keys.include?('random_url')
      if random_url
        self.random_key = SecureRandom.hex(30)
      else
        self.random_key = nil
      end
    end

    if self.changes.keys.include?('private') and !private
      self.random_url = false
      self.random_key = nil
    end
  end
end
