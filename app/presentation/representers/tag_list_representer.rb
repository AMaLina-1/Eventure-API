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

      collection :tags, extend: TagSingle, class: OpenStruct
    end
  end
end
