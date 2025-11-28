# frozen_string_literal: true

module Eventure
  module Response
    # List of projects
    ActivityLike = Struct.new(:serno, :user_likes, :like_counts)
  end
end
