# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for district list
    class DistrictList < Roar::Decorator
      include Roar::JSON

      property :city
      collection :districts
    end
  end
end
