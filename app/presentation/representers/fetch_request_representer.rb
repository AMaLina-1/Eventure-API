# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

# Represents essential api information for API output
module Eventure
  module Representer
    # Representer object for api fetch requests
    class FetchRequest < Roar::Decorator
      include Roar::JSON

      property :api_name
      property :number
      property :id
    end
  end
end
