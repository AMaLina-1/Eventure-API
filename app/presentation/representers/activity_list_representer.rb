# frozen_string_literal: true

require 'ostruct'
require 'roar/decorator'
require 'roar/json'
require_relative 'activity_single_representer'

module Eventure
  module Representer
    # Representer for activity list
    class ActivityList < Roar::Decorator
      include Roar::JSON

      collection :activities, extend: ActivitySingle, class: OpenStruct
    end
  end
end
