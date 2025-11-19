# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for a activity detail
    class ActivityDetail < Roar::Decorator
      include Roar::JSON

      property :serno
      property :name
      property :voice
      property :location
      property :start_time
      property :duration
      property :relate_url
    end
  end
end
