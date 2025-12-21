# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module Eventure
  module Value
    # Value object representing an activity location (city + building/address)
    class Location < Dry::Struct
      include Dry.Types

      attribute :building, Strict::String
      attribute? :city_name, Strict::String.optional.default(nil)

      def to_s
        building
      end

      def self.normalize_building(building, city_name)
        building_str = building.to_s.strip
        normalized_city = normalize_city(city_name)

        return normalized_city if building_str.empty?
        return building_str if normalized_city.empty?

        prefix_city_unless_present(building_str, normalized_city)
      end

      def self.prefix_city_unless_present(building_str, normalized_city)
        normalized_building = normalize_city(building_str)
        return building_str if normalized_building.start_with?(normalized_city)

        "#{normalized_city}#{building_str}"
      end

      def self.normalize_city(str)
        str.to_s.strip.tr('臺', '台')
      end

      def city
        self.class.normalize_city(city_name)
      end

      def district
        ''
      end
    end
  end
end
