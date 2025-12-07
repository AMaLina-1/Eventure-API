# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'
require 'date'
require_relative 'tag'
require_relative 'relatedata'
require_relative '../values/location'
require_relative '../values/activity_date'

module Eventure
  module Entity
    # Domain Entity for an activity
    class Activity < Dry::Struct
      include Dry.Types

      attribute :serno,        Strict::String
      attribute :name,         Strict::String
      attribute :detail,       Strict::String
      attribute :location,     Eventure::Value::Location
      attribute :voice,        Strict::String
      attribute :organizer,    Strict::String
      attribute :tags,         Strict::Array.of(Tag).default([].freeze)
      attribute :relate_data,  Strict::Array.of(RelateData).default([].freeze)
      attribute :activity_date, Eventure::Value::ActivityDate
      # attribute? :likes_count, Strict::Integer

      def initialize(*args)
        super(*args)
        @likes_count = 0
      end

      # 讓舊 view 照樣可用
      def start_time = activity_date.start_time
      def end_time   = activity_date.end_time

      def likes_count
        @likes_count ||= 0
      end

      def to_entity
        self
      end

      # def relate_data
      #   Eventure::Entity::Activity.relate_data
      # end

      def tag
        tags.map(&:tag)
      end

      def relate_url
        relate_data.map(&:relate_url)
      end

      def relate_title
        relate_data.map(&:relate_title)
      end

      def city
        location.city
      end

      def district
        location.district
      end

      def building
        location.to_s
      end

      def region
        location.city
      end

      def add_likes
        @likes_count = (@likes_count || 0 ) + 1
      end

      def remove_likes
        @likes_count = (@likes_count || 0 )
        @likes_count -= 1 if @likes_count.positive?
      end

      def status
        activity_date.status
      end

      def duration
        activity_date.duration
      end
    end
  end
end

# start_time = DateTime.parse("2025-11-01T19:00:00")
# end_time = DateTime.parse("2025-11-03T7:10:00")
