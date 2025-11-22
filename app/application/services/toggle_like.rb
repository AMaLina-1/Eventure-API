# frozen_string_literal: true

require 'dry/monads'

module Eventure
  module Service
    # Service to toggle like status for an activity
    class ToggleLike # rubocop:disable Style/Documentation
      include Dry::Monads[:result]

      DB_ERR = 'Cannot access database'
      NOT_FOUND = 'Activity not found'

      def call(session:, serno:)
        session[:user_likes] ||= []

        activity = find_activity(serno)
        return Failure(Response::ApiResult.new(status: :not_found, message: NOT_FOUND)) if activity.nil?

        toggle_like!(session, activity, serno)
        persist_likes(activity)

        Success(Response::ApiResult.new(status: :ok, message: OpenStruct.new(likes_count: activity.likes_count)))
      rescue StandardError
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end

      private

      def find_activity(serno)
        Eventure::Repository::Activities.find_serno(serno)
      end

      def toggle_like!(session, activity, serno)
        if session[:user_likes].include?(serno)
          activity.remove_likes
          session[:user_likes].delete(serno)
        else
          activity.add_likes
          session[:user_likes] << serno
        end
      end

      def persist_likes(activity)
        Eventure::Repository::Activities.update_likes(activity)
      end
    end
  end
end
