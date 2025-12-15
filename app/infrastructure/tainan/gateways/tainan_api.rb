# frozen_string_literal: true

require 'http'

module Eventure
  module Tainan
    # library for tainan activity api
    class Api
      def initialize
        @path = 'https://soa.tainan.gov.tw/Api/Service/Get/d6fc3d1b-4b5b-4205-9014-5118e37f0971'
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
