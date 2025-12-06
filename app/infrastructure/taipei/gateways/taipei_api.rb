# frozen_string_literal: true

require 'http'

module Eventure
  module Taipei
    # library for taipei activity api
    class Api
      def initialize
        @path = 'https://www.travel.taipei/open-api/zh-tw/Events/Calendar'
      end

      # return parsed json
      def parsed_json(top)
        url = "#{@path}?top=#{top}"
        Request.new.get(url).parse
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
