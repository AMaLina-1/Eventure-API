# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Service to list cities
    class ListCity
      include Dry::Transaction

      step :fetch_cities

      DB_ERR = 'Cannot access database'

      private

      def fetch_cities(input)
        activities = Repository::For.klass(Entity::Activity).all
        # drop nil/blank cities to avoid empty option in UI
        cities = activities.map(&:city).map { |city| city.to_s.strip }.reject(&:empty?).uniq
        list = Eventure::Response::CityList.new(cities)
        Response::ApiResult.new(status: :ok, message: list)
                           .then { |result| Success(result) }
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
