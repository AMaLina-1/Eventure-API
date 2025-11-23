# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for city list
    class CityList < Roar::Decorator
      include Roar::JSON

      collection :cities
    end
  end
end
