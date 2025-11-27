# frozen_string_literal: true

require 'dry/transaction'
require 'ostruct'

module Eventure
  module Service
    # Service to list tags
    class ListTag
      include Dry::Transaction

      step :fetch_tags

      DB_ERR = 'Cannot access database'

      private

      def fetch_tags(_input)
        activities = Repository::For.klass(Entity::Activity).all
        # extract tag strings and wrap into simple objects that the representer expects
        tags = activities.flat_map { |activity| Array(activity.tags).map { |t| t.respond_to?(:tag) ? t.tag : t.to_s } }
                         .uniq
                         .map { |tag_text| OpenStruct.new(tag: tag_text) }

        list = Eventure::Response::TagList.new(tags)
        Response::ApiResult.new(status: :ok, message: list)
                           .then { |result| Success(result) }
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
