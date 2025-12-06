# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module Eventure
  module Entity
    # Domain Entity for a tag
    class Tag < Dry::Struct
      include Dry.Types

      attribute :tag, String
    end
  end
end
