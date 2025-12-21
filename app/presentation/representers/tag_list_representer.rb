# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'
require_relative 'tag_single_representer'

module Eventure
  module Representer
    # Representer for tag list
    class TagList < Roar::Decorator
      include Roar::JSON

      def initialize(represented, language: 'zh-TW')
        super(represented)
        @language = language
      end

      # Return tags as plain strings so frontends that expect an array of
      # strings (e.g. ["教育文化", "文化藝術"]) can consume the API
      # easily. We accept either OpenStruct/tag objects or plain strings.
      collection :tags, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        Array(tags).map do |t|
          if lang == 'en' && t.respond_to?(:tag_en) && t.tag_en && !t.tag_en.empty?
            t.tag_en
          elsif t.respond_to?(:tag)
            t.tag.to_s
          else
            t.to_s
          end
        end
      }

      # override to_json to accept language option
      def to_json(*args)
        to_hash(user_options: { language: @language }).to_json
      end
    end
  end
end
