# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Eventure
  module Service
    # update likes service
    class UpdateLikes
      include Dry::Monads[:result, :do]

      DB_ERR = 'Cannot access database'
      NOT_FOUND = 'Activity not found'

      def call(user:, serno:)
        activity = yield find_activity(serno)
        updated_user = toggle_like(user, serno)
        yield save_to_db(activity, updated_user.user_likes.include?(serno))
        Success(Response::ApiResult.new(status: :ok, message: OpenStruct.new(user_likes: updated_user.user_likes)))
      end

      private

      def find_activity(serno)
        activity = Eventure::Repository::Activities.find_serno(serno)
        return Success(activity) if activity

        Failure(Response::ApiResult.new(status: :not_found, message: NOT_FOUND))
      end

      def toggle_like(user, serno)
        current_likes = user.user_likes.dup

        if current_likes.include?(serno)
          current_likes.delete(serno)
        else
          current_likes << serno
        end

        Eventure::Entity::User.new(
          user_id: user.user_id,
          user_date: user.user_date,
          user_theme: user.user_theme,
          user_region: user.user_region,
          user_saved: user.user_saved,
          user_likes: current_likes
        )
      end

      def save_to_db(activity, is_liked)
        if is_liked
          activity.add_likes
        else
          activity.remove_likes
        end

        Eventure::Repository::Activities.update_likes(activity)
        Success(activity)
      rescue StandardError => e
        Failure(Response::ApiResult.new(status: :internal_error, message: DB_ERR))
      end
    end
  end
end
