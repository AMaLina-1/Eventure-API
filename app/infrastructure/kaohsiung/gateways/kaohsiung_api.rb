# frozen_string_literal: true

require 'http'

module Eventure
  module Kaohsiung
    # library for kaohsiung activity api
    class Api
      def initialize
        @path = 'https://data.kcg.gov.tw/Json/Get/80bbbbd3-9ee4-4244-98e9-b4c08deda91b'
      end

      # return parsed json
      def parsed_json(_top = nil)
        Request.new.get(@path).parse
      end

      # use 'top' to get http response
      class Request
        def get(url)
          http_response = HTTP.timeout(10).headers('Accept' => 'application/json').get(url)
          raise 'Request Failed' unless http_response.status.success?

          http_response
        
        rescue HTTP::TimeoutError, HTTP::ConnectionError => e
          raise "Request Failed: #{e.class} - #{e.message}"
        end
      end
    end
  end
end
