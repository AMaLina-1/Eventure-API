# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for worker message
    class WorkerFetchData < Roar::Decorator
      include Roar::JSON

      property :api_name
      property :number
    end
  end
end
