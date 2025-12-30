# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Service to list districts
    class ListDistrict
      include Dry::Transaction

      step :fetch_districts

      DB_ERR = 'Cannot access database'

      private

      def fetch_districts(input)
        activities = Repository::For.klass(Entity::Activity).all
        districts = activities.group_by(&:city).transform_values do |acts|
          ['全區'] + acts.map(&:district).uniq
        end
        list = Eventure::Response::DistrictsList.new(districts)
        Response::ApiResult.new(status: :ok, message: list)
                           .then { |result| Success(result) }
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
