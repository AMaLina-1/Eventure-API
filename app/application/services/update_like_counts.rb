# frozen_string_literal: true

require 'dry/transaction'

module Eventure
  module Service
    # Transaction to update like counts (input: serno, user_likes)
    class UpdateLikeCounts
      include Dry::Transaction

      step :fetch_activity
      step :update_like_session
      step :save_like_db
      step :wrap_in_response

      private

      DB_ERR = 'Cannot access database'
      NOT_FOUND = 'Activity not found'

      def fetch_activity(input)
        input[:activity] = Eventure::Repository::Activities.find_serno(input[:serno])
        if input[:activity]
          Success(input)
        else
          Failure(Response::ApiResult.new(status: :not_found, message: NOT_FOUND))
        end
      end

      def update_like_session(input)
        puts 'user_likes before: ', input[:user_likes]
        if input[:user_likes].include?(input[:serno])
          input[:activity].remove_likes
          input[:user_likes].delete(input[:serno])
        else
          input[:activity].add_likes
          input[:user_likes] << input[:serno]
        end
        puts 'user_likes after: ', input[:user_likes]
        Success(input)
      rescue StandardError => e
        Failure(Response::ApiResult.new(status: :internal_error, message: e.message))
      end

      def save_like_db(input)
        Eventure::Repository::Activities.update_likes(input[:activity])
        Success(input)
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      def wrap_in_response(input)
        result = Response::ActivityLike.new(serno: input[:serno], user_likes: input[:user_likes], like_counts: input[:activity].likes_count)
        Success(Response::ApiResult.new(status: :ok, message: result))
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: 'Cannot wrap response'))
      end
    end
  end
end
