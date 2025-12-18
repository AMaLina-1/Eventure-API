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

      # Return tags as plain strings so frontends that expect an array of
      # strings (e.g. ["教育文化", "文化藝術"]) can consume the API
      # easily. We accept either OpenStruct/tag objects or plain strings.
      collection :tags, getter: lambda { |represented:, **|
        Array(represented.tags).map do |tag|
          tag.respond_to?(:tag) ? tag.tag.to_s : tag.to_s
        end
      }
    end
  end
end
