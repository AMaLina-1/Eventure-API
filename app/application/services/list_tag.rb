# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Service to list tags
    class ListTag
      include Dry::Transaction

      step :fetch_tags

      DB_ERR = 'Cannot access database'

      private

      def fetch_tags(input)
        activities = Repository::For.klass(Entity::Activity).all
        tags = activities.flat_map { |activity| activity.tags.map(&:tag) }.uniq
        list = Eventure::Response::TagList.new(tags)
        Response::ApiResult.new(status: :ok, message: list)
          .then { |result| Success(result) }
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
