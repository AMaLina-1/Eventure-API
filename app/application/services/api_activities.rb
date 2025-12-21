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
      # step :store_tainan_activities
      step :store_kaohsiung_activities
      step :wrap_in_response

      private

      def define_parameters(input)
        # calculate api parameters for each api source
        input[:missing] = []
        input[:processing] = []
        Success(input)
      end

      def store_hccg_activities(input)
        # cache = Eventure::Cache::Client.new(App.config)
        # return Success(input) if cache.get('fetch_hccg') == 'true'
        return Success(input) if Eventure::Repository::Status.get_status('hccg') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'hccg'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'hccg', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching HCCG activities now. Please check back later'))
        input[:processing] << 'HCCG'
        # Failure(Response::ApiResult.new(
        #   status: :processing,
        #   message: {
        #     request_id: input[:request_id],
        #     api: 'hccg',
        #     msg: PROCESSING_MSG
        #   }
        # ))
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch HCCG activities: #{e.message}"
        input[:missing] << 'HCCG'
        Success(input)
        # Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot fetch HCCG activities'))
      end

      def store_taipei_activities(input)
        return Success(input) if Eventure::Repository::Status.get_status('taipei') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'taipei'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'taipei', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching Taipei activities now. Please check back later'))
        input[:processing] << 'Taipei'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taipei activities: #{e.message}"
        input[:missing] << 'Taipei'
        Success(input)
      end

      def store_new_taipei_activities(input)
        return Success(input) if Eventure::Repository::Status.get_status('new_taipei') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'new_taipei'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'new_taipei', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching New Taipei activities now. Please check back later'))
        input[:processing] << 'New Taipei'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch New Taipei activities: #{e.message}"
        input[:missing] << 'New Taipei'
        Success(input)
      end

      def store_taichung_activities(input)
        return Success(input) if Eventure::Repository::Status.get_status('taichung') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'taichung'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'taichung', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching Taichung activities now. Please check back later'))
        input[:processing] << 'Taichung'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taichung activities: #{e.message}"
        input[:missing] << 'Taichung'
        Success(input)
      end

      def store_tainan_activities(input)
        return Success(input) if Eventure::Repository::Status.get_status('tainan') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'tainan'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'tainan', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching Tainan activities now. Please check back later'))
        input[:processing] << 'Tainan'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Tainan activities: #{e.message}"
        input[:missing] << 'Tainan'
        Success(input)
      end

      def store_kaohsiung_activities(input)
        return Success(input) if Eventure::Repository::Status.get_status('kaohsiung') == 'true'

        Messaging::Queue.new(App.config.QUEUE_URL, App.config)
          .send(fetch_request_json(input, 'kaohsiung'))
          # .send(Eventure::Representer::WorkerFetchData.new(OpenStruct.new(api_name: 'kaohsiung', number: input[:total])).to_json)
        # Failure(Response::ApiResult.new(status: :processing, message: 'Fetching Kaohsiung activities now. Please check back later'))
        input[:processing] << 'Kaohsiung'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Kaohsiung activities: #{e.message}"
        input[:missing] << 'Kaohsiung'
        Success(input)
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

      def fetch_request_json(input, api_name)
        Response::FetchRequest.new(api_name, input[:total], input[:request_id])
          .then { Representer::FetchRequest.new(_1) }
          .then(&:to_json)
      end
    end
  end
end
