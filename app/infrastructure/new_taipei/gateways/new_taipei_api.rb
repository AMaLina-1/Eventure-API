# frozen_string_literal: true

require 'http'

module Eventure
  module NewTaipei
    # library for new taipei activity api
    class Api
      def initialize
        @path = 'https://data.ntpc.gov.tw/api/datasets/029e3fc2-1927-4534-8702-da7323be969b/json'
      end

      # return parsed json
      def parsed_json(top)
        url = "#{@path}?page=0&size=#{top}"
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
