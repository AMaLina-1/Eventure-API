# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module Eventure
  module Value
    # value object for activities
    class Location < Dry::Struct
      include Dry.Types

      attribute :building, Strict::String
      attribute? :city_name, Strict::String.optional.default(nil)

      def to_s
        building
      end

      # Prefix city to building when missing; use city when building blank
      def self.normalize_building(building, city_name)
        b = building.to_s.strip
        c = city_name.to_s.strip
        return c if b.empty?
        return b if c.empty?

        b_norm = b.tr('臺', '台')
        c_norm = c.tr('臺', '台')

        return b if b_norm.start_with?(c_norm)

        "#{c}#{b}"
      end

      def city
        city_name
      end

      def district
        ''
      end
    end
  end
end
