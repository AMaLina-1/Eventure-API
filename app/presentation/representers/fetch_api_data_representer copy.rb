# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for activity list
    class FetchApiData < Roar::Decorator
      include Roar::JSON

      property :msg
    end
  end
end
