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
        # if Eventure::Repository::Status.get_status('hccg') == 'true'
        #   input[:processing].delete('HCCG')
        #   return Success(input)
        # end
        input[:processing] = put_processing(input[:processing], 'hccg', 'HCCG')
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'hccg'))
        # input[:processing] << 'HCCG'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch HCCG activities: #{e.message}"
        input[:missing] << 'HCCG'
        Success(input)
      end

      def store_taipei_activities(input)
        # if Eventure::Repository::Status.get_status('taipei') == 'true'
        #   input[:processing].delete('Taipei')
        #   return Success(input)
        # end
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'taipei'))
        # input[:processing] << 'Taipei'
        input[:processing] = put_processing(input[:processing], 'taipei', 'Taipei')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taipei activities: #{e.message}"
        input[:missing] << 'Taipei'
        Success(input)
      end

      def store_new_taipei_activities(input)
        # if Eventure::Repository::Status.get_status('new_taipei') == 'true'
        #   input[:processing].delete('New Taipei')
        #   return Success(input)
        # end
        input[:processing] = put_processing(input[:processing], 'new_taipei', 'New Taipei')
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'new_taipei'))
        # input[:processing] << 'New Taipei'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch New Taipei activities: #{e.message}"
        input[:missing] << 'New Taipei'
        Success(input)
      end

      def store_taichung_activities(input)
        # if Eventure::Repository::Status.get_status('taichung') == 'true'
        #   input[:processing].delete('Taichung')
        #   return Success(input)
        # end
        input[:processing] = put_processing(input[:processing], 'taichung', 'Taichung')
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'taichung'))
        # input[:processing] << 'Taichung'
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taichung activities: #{e.message}"
        input[:missing] << 'Taichung'
        Success(input)
      end

      def store_tainan_activities(input)
        # if Eventure::Repository::Status.get_status('tainan') == 'true'
        #   input[:processing].delete('Tainan')
        #   return Success(input)
        # end
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'tainan'))
        # input[:processing] << 'Tainan'
        input[:processing] = put_processing(input[:processing], 'tainan', 'Tainan')
        Success(input)
      rescue StandardError => e
        puts "Warning: Failed to fetch Tainan activities: #{e.message}"
        input[:missing] << 'Tainan'
        Success(input)
      end

      def store_kaohsiung_activities(input)
        # if Eventure::Repository::Status.get_status('kaohsiung') == 'true'
        #   input[:processing].delete('Kaohsiung')
        #   return Success(input)
        # end
        input[:processing] = put_processing(input[:processing], 'kaohsiung', 'Kaohsiung')
        # Messaging::Queue.new(App.config.QUEUE_URL, App.config)
        #                 .send(fetch_request_json(input, 'kaohsiung'))
        # input[:processing] << 'Kaohsiung'
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

      def put_processing(processing_list, api_name, show_name)
        if Eventure::Repository::Status.get_status(api_name) == 'true'
          processing_list.delete(show_name)
        else
          Messaging::Queue.new(App.config.QUEUE_URL, App.config)
                          .send(fetch_request_json(input, api_name))
          processing_list << show_name
        end
        processing_list
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
