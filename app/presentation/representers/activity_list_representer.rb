# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'
require_relative 'activity_single_representer'

module Eventure
  module Representer
    # Representer for activity list
    class ActivityList < Roar::Decorator
      include Roar::JSON

      def initialize(represented, language: 'zh-TW')
        super(represented)
        @language = language
      end

      collection :activities, extend: ActivitySingle, class: OpenStruct

      # override to_json to accept language option
      def to_json(*args)
        to_hash(user_options: { language: @language }).to_json
      end
    end
  end
end
