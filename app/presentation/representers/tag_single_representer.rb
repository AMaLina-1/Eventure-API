# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for a single tag
    class TagSingle < Roar::Decorator
      include Roar::JSON

      property :tag
    end
  end
end
