# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Transaction to filter activities (input: filters)
    class FilteredActivities
      include Dry::Transaction

      step :fetch_all_activities
      step :filter_by_tags
      step :filter_by_city
      step :filter_by_districts
      step :filter_by_dates
      step :wrap_in_response

      private

      DB_ERR = 'Cannot access database'
      BAD_REQ = 'Start date cannot be later than end date'

      def fetch_all_activities(input)
        input[:all_activities] = Eventure::Repository::Activities.all
        input[:filtered_activities] = input[:all_activities]
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def filter_by_tags(input)
        tag_set = input[:filters][:tag]

        unless tag_set.nil? || tag_set.empty?
          input[:filtered_activities] = input[:filtered_activities].select do |activity|
            tags = Array(activity.tags).map { |ac_tag| ac_tag.respond_to?(:tag) ? ac_tag.tag.to_s : ac_tag.to_s }
            tags.intersect?(tag_set)
          end
        end
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def filter_by_city(input)
        city = input[:filters][:city].to_s
        unless city.empty?
          input[:filtered_activities] = input[:filtered_activities].select { |activity| activity.city == city }
        end
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def filter_by_districts(input)
        dists = Array(input[:filters][:districts])
        unless dists.empty? || dists.include?('全區')
          input[:filtered_activities] = input[:filtered_activities].select do |activity|
            dists.include?(activity.district)
          end
        end
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def filter_by_dates(input)
        start_raw = input[:filters][:start_date]
        end_raw   = input[:filters][:end_date]
        return Success(input) unless start_raw || end_raw

        start_dt = parse_date(start_raw)
        end_dt   = parse_date(end_raw)

        if start_dt && end_dt
          return Failure(Response::ApiResult.new(status: :bad_request, message: BAD_REQ)) if start_dt > end_dt

          input[:filtered_activities] = input[:filtered_activities].select do |ac_date|
            ad = ac_date.activity_date
            ad&.start_time&.between?(start_dt, end_dt)
          end
        elsif start_dt
          input[:filtered_activities] = input[:filtered_activities].select do |ac_date|
            ad = ac_date.activity_date
            ad&.start_time && ad.start_time >= start_dt
          end
        elsif end_dt
          input[:filtered_activities] = input[:filtered_activities].select do |ac_date|
            ad = ac_date.activity_date
            ad&.start_time && ad.start_time <= end_dt
          end
        end
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def wrap_in_response(input)
        # result_hash = {
        #   # all_activities: input[:all_activities],
        #   # filtered_activities: input[:filtered_activities]
        #   activities: input[:filtered_activities]
        # }
        result = Response::ActivitiesList.new(activities: input[:filtered_activities])
        Success(Response::ApiResult.new(status: :ok, message: result))
      end

      # Helper – safe parse
      def parse_date(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?

        DateTime.parse(raw.to_s)
      rescue StandardError
        nil
      end
    end
  end
end
