# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Service to list activities
    class ListActivity
      include Dry::Transaction

      step :fetch_activities

      DB_ERR = 'Cannot access database'

      private

      def fetch_activities(input)
        activities = Repository::For.klass(Entity::Activity).all
        list = Eventure::Response::ActivitiesList.new(
          activities.map { |activity| Entity::Activity.new(activity) }
        )
        Response::ApiResult.new(status: :ok, message: list)
          .then { |result| Success(result) }
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
