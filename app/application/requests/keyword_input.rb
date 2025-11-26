# frozen_string_literal: true

require 'base64'
require 'dry/monads'
require 'json'

module Eventure
  module Request
    # Project list request parser
    class KeywordInput
      include Dry::Monads::Result::Mixin

      def initialize(params)
        @params = params
      end

      # Use in API to parse incoming list requests
      def call
        Success(
          JSON.parse(decode(@params))
        )
      rescue StandardError
        Failure(
          Response::ApiResult.new(
            status: :bad_request,
            message: 'activity not found'
          )
        )
      end

      # Decode params
      def decode(param)
        Base64.urlsafe_decode64(param)
      end

      # Client App will encode params to send as a string
      # - Use this method to create encoded params for testing
      def self.to_encoded(list)
        Base64.urlsafe_encode64(list.to_json)
      end

      # Use in tests to create a ProjectList object from a list
      def self.to_request(list)
        KeywordInput.new('list' => to_encoded(list))
      end
    end
  end
end

# require 'dry/monads'

# module Eventure
#   module Request
#     # Parse + validate keyword coming into the API
#     class KeywordInput
#       include Dry::Monads::Result::Mixin

#       VALID_CHAR = /^[\p{Han}\p{Latin}\d\s.-]+$/

#       def initialize(params)
#         @params = params
#       end

#       def call
#         raw = @params['keyword']

#         keyword = (raw || '').to_s.strip
#         return Success(keyword: '') if keyword.empty? # 空字串代表不過濾，也算合法

#         if VALID_CHAR.match?(keyword)
#           Success(keyword:)
#         else
#           Failure(
#             Response::ApiResult.new(
#               status: :bad_request,
#               message: 'Keywords cannot contain special characters'
#             )
#           )
#         end
#       rescue StandardError
#         Failure(
#           Response::ApiResult.new(
#             status: :internal_error,
#             message: 'Cannot process keyword input'
#           )
#         )
#       end

#       def self.to_request(keyword)
#         new('keyword' => keyword)
#       end
#     end
#   end
# end
