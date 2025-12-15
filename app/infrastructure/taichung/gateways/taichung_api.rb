# frozen_string_literal: true

require 'http'

module Eventure
  module Taichung
    # library for taichung activity api
    class Api
      def initialize
        @path = 'https://datacenter.taichung.gov.tw/swagger/OpenData/4c5157cc-34ed-45fb-ba03-34e6cbbfc9d8'
      end

      # return parsed json
      def parsed_json(_top = nil)
        Request.new.get(@path).parse
      end

      # use 'top' to get http response
      class Request
        def get(url)
          http_response = HTTP.headers('Accept' => 'application/json').get(url)
          raise 'Request Failed' unless http_response.status.success?

          http_response
        end
      end
    end
  end
end
