# frozen_string_literal: true

require_relative '../../domain/values/filter'
require 'dry/transaction'

module Eventure
  module Service
    # Service for activities
    class ApiActivities
      include Dry::Transaction

      step :define_parameters
      step :store_hccg_activities
      # step :store_taipei_activities
      step :store_new_taipei_activities
      step :store_taichung_activities
      step :store_tainan_activities
      step :store_kaohsiung_activities
      step :wrap_in_response

      private

      def define_parameters(input)
        input[:missing] = []
        input[:processing] = []
        Success(input)
      end

      def store_hccg_activities(input)
        input[:processing] = put_processing(input, 'hccg', 'HCCG')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch HCCG activities: #{e.message}"
        input[:missing] << 'HCCG'
        Success(input)
      end

      def store_taipei_activities(input)
        input[:processing] = put_processing(input, 'taipei', 'Taipei')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taipei activities: #{e.message}"
        input[:missing] << 'Taipei'
        Success(input)
      end

      def store_new_taipei_activities(input)
        input[:processing] = put_processing(input, 'new_taipei', 'New Taipei')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch New Taipei activities: #{e.message}"
        input[:missing] << 'New Taipei'
        Success(input)
      end

      def store_taichung_activities(input)
        input[:processing] = put_processing(input, 'taichung', 'Taichung')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taichung activities: #{e.message}"
        input[:missing] << 'Taichung'
        Success(input)
      end

      def store_tainan_activities(input)
        input[:processing] = put_processing(input, 'tainan', 'Tainan')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Tainan activities: #{e.message}"
        input[:missing] << 'Tainan'
        Success(input)
      end

      def store_kaohsiung_activities(input)
        input[:processing] = put_processing(input, 'kaohsiung', 'Kaohsiung')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Kaohsiung activities: #{e.message}"
        input[:missing] << 'Kaohsiung'
        Success(input)
      end

      def wrap_in_response(input)
        if input[:processing] != []
          wrapped_message = { request_id: input[:request_id], msg: 'Processing the fetching request...' }
          Failure(Response::ApiResult.new(status: :processing, message: wrapped_message))
        elsif input[:missing] == []
          wrap_result
        else
          wrap_result(input[:missing])
        end
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot wrap response'))
      end

      def fetch_request_json(input, api_name)
        Response::FetchRequest.new(api_name, input[:total], input[:request_id])
                              .then { Representer::FetchRequest.new(it) }
                              .then(&:to_json)
      end

      def put_processing(input, api_name, show_name)
        if Eventure::Repository::Status.get_status(api_name) == 'true'
          input[:processing].delete(show_name)
        else
          Messaging::Queue.new(App.config.QUEUE_URL, App.config)
                          .send(fetch_request_json(input, api_name))
          input[:processing] << show_name
        end
        input[:processing]
      end

      def wrap_result(missing = nil)
        if missing.nil?
          result = Response::FetchApiData.new(msg: 'Activities saved successfully')
          Success(Response::ApiResult.new(status: :ok, message: result))
        else
          result = Response::FetchApiData.new(msg: "Cannot fetch #{missing.join(', ')} activities")
          Success(Response::ApiResult.new(status: :no_content, message: result))
        end
      end
    end
  end
end
