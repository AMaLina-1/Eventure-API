# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for like/unlike result of an activity
    class ActivityLike < Roar::Decorator
      include Roar::JSON

      property :serno       # 給前端知道是哪一個活動
      property :likes_count # 最新愛心數
      property :user_likes  # 使用者目前喜歡的活動清單
    end
  end
end
