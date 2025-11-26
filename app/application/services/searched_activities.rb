# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Simple service to search activities by a keyword.
    # Input can be: { keyword: 'foo' } or { filters: { keyword: 'foo' } }
    class SearchedActivities
      include Dry::Transaction

      step :fetch_all_activities
      step :filter_by_keyword
      step :wrap_in_response

      private

      DB_ERR = 'Cannot access database'

      def fetch_all_activities(input)
        input[:all_activities] = Eventure::Repository::Activities.all
        input[:filtered_activities] = input[:all_activities]
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def filter_by_keyword(input)
        kw = if input.key?(:keyword)
               input[:keyword]
             elsif input[:filters] && input[:filters].key?(:keyword)
               input[:filters][:keyword]
             end

        # If no keyword provided, return all
        return Success(input) if kw.nil? || kw.to_s.strip.empty?

        pattern = kw.to_s.downcase

        input[:filtered_activities] = input[:filtered_activities].select do |activity|
          name_match = activity.name.to_s.downcase.include?(pattern)
          detail_match = activity.detail.to_s.downcase.include?(pattern)
          organizer_match = activity.organizer.to_s.downcase.include?(pattern)
          city_match = activity.city.to_s.downcase.include?(pattern)

          tags = Array(activity.tags).map { |t| t.respond_to?(:tag) ? t.tag.to_s.downcase : t.to_s.downcase }
          tags_match = tags.any? { |t| t.include?(pattern) }

          name_match || detail_match || organizer_match || city_match || tags_match
        end

        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def wrap_in_response(input)
        result_hash = {
          all_activities: input[:all_activities],
          filtered_activities: input[:filtered_activities]
        }
        Success(Response::ApiResult.new(status: :ok, message: result_hash))
      end
    end
  end
end
