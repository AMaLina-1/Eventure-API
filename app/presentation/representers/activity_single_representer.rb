# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for a single activity
    class ActivitySingle < Roar::Decorator
      include Roar::JSON

      property :serno
      property :name
      property :location
      property :tag
      property :status
      property :likes_count
      property :start_time
    end
  end
end
