# frozen_string_literal: true

require 'date'
require_relative '../../domain/values/filter'
require 'dry/transaction'
# require_relative '../../domain/entities/user_temp'

module Eventure
  module Service
    # Service for activities
    class ApiActivities
      include Dry::Transaction

      step :define_parameters
      step :fetch_hccg_activities
      step :fetch_taipei_activities
      step :fetch_new_taipei_activities
      step :combine_activities
      step :save_activities
      step :wrap_in_response

      private

      def define_parameters(input)
        # calculate api parameters for each api source
        input[:missing] = []
        Success(input)
      end

      def fetch_hccg_activities(input)
        input[:hccg_activities] = Eventure::Hccg::ActivityMapper.new.find(input[:total]).map(&:to_entity)
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch HCCG activities: #{e.message}"
        input[:hccg_activities] = []
        input[:missing] << 'HCCG'
        Success(input)
        # Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot fetch HCCG activities'))
      end

      def fetch_taipei_activities(input)
        input[:taipei_activities] = Eventure::Taipei::ActivityMapper.new.find(1).map(&:to_entity)
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taipei activities: #{e.message}"
        input[:taipei_activities] = []
        input[:missing] << 'Taipei'
        Success(input)
        # Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot fetch Taipei activities'))
      end

      def fetch_new_taipei_activities(input)
        input[:new_taipei_activities] = Eventure::NewTaipei::ActivityMapper.new.find(input[:total]).map(&:to_entity) || []
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch New Taipei activities: #{e.message}"
        input[:new_taipei_activities] = []
        input[:missing] << 'New Taipei'
        Success(input)
        # Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot fetch New Taipei activities'))
      end

      def combine_activities(input)
        input[:combined_activities] = input[:hccg_activities] + input[:taipei_activities] + input[:new_taipei_activities]
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to combine activities: #{e.message}"
        Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot combine activities'))
      end

      def save_activities(input)
        Repository::For.entity(input[:combined_activities].first).create(input[:combined_activities])
        Success(input)
      rescue StandardError => e
        puts "Error saving activities: #{e.message}"
        Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot save activities'))
      end

      def wrap_in_response(input)
        if input[:missing] == []
          result = Response::FetchApiData.new(msg: 'Activities saved successfully')
          Success(Response::ApiResult.new(status: :ok, message: result))
        else
          result = Response::FetchApiData.new(msg: "Cannot fetch #{input[:missing].join(', ')} activities")
          Success(Response::ApiResult.new(status: :no_content, message: result))
        end
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot wrap response'))
      end
      

      # def parse_date_range(start_raw, end_raw)
      #   parts = [start_raw, end_raw].map { |date| date.to_s.strip }
      #   return [] if parts.any?(&:empty?) # 只要有一邊沒填 → 不啟用日期篩選

      #   [Date.strptime(parts[0], '%Y-%m-%d'),
      #    Date.strptime(parts[1], '%Y-%m-%d')] # 兩邊都有 → 轉成 Date[]
      # rescue ArgumentError
      #   [] # 格式錯誤也視為沒選
      # end
    end
  end
end
  