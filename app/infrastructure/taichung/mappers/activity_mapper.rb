# frozen_string_literal: true

require 'date'

require_relative '../../../domain/entities/activity'
require_relative '../../../domain/entities/tag'
require_relative '../../../domain/entities/relatedata'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Taichung
    # data mapper: taichung api response -> Activity entity
    class ActivityMapper
      def initialize(gateway_class = Taichung::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new
        @parsed_data = nil
      end

      def find(top)
        raw = @gateway.parsed_json(top)
        # Taichung API returns Array directly, not wrapped in {data: [...]}
        @parsed_data = raw.is_a?(Array) ? raw : raw['data']
        build_entity
      end

      def build_entity
        @parsed_data.map { |line| DataMapper.new(line).to_entity }
      end

      def self.to_attr_hash(entity)
        {
          serno: entity.serno,
          name: entity.name,
          detail: entity.detail,
          start_time: entity.start_time.to_time.utc,
          end_time: entity.end_time.to_time.utc,
          location: entity.location.to_s,
          voice: entity.voice,
          organizer: entity.organizer
        }
      end

      # Extracts entity elements from raw data
      class DataMapper
        def initialize(data)
          @data = data
        end

        def to_entity
          Eventure::Entity::Activity.new(
            serno:, name:, detail:,
            activity_date: Eventure::Value::ActivityDate.new(
              start_time: start_time,
              end_time: end_time
            ),
            location:, voice:, organizer:, tags:, relate_data:
          )
        end

        def serno
          @data['Id(編號)'].to_s
        end

        def name
          @data['title(活動名稱)']
        end

        def detail
          @data['content(內容)']
        end

        def start_time
          DateTime.parse(@data['activitystart(活動起日)']).new_offset(0)
        end

        def end_time
          DateTime.parse(@data['activityclose(活動迄日)']).new_offset(0)
        end

        def location
          self.class.build_location(@data, '台中市')
        end

        def voice
          @data['content(內容)']
        end

        def organizer
          @data['mainunit(主辦單位)']
        end

        def tags
          self.class.build_tags(@data['attribute(活動類型)'])
        end

        def relate_data
          self.class.build_relate_data(@data['relatedLink(相關連結)'])
        end

        def self.build_location(data, city)
          address = extract_address(data['location(座標資訊)'])
          normalized = Eventure::Value::Location.normalize_building(address, city)
          Eventure::Value::Location.new(building: normalized, city_name: city)
        end

        def self.extract_address(location_json)
          return '' if location_json.to_s.strip.empty?

          JSON.parse(location_json).fetch('address', '')
        rescue JSON::ParserError
          ''
        end

        def self.build_tags(class_name)
          name = class_name.to_s.strip
          return [] if name.empty?

          [Eventure::Entity::Tag.new(tag: name)]
        end

        def self.build_relate_data(resource)
          normalize_relate_resource(resource)
            .map { |item| build_relate_data_entity(item) }
            .compact
        end

        def self.build_relate_data_entity(item)
          url =
            if item.is_a?(String)
              item
            elsif item.is_a?(Hash)
              item['relatedLink(相關連結)']
            end

          return unless url&.start_with?('http')

          Eventure::Entity::RelateData.new(
            relatedata_id: nil, relate_title: '', relate_url: url
          )
        end

        def self.normalize_relate_resource(resource)
          case resource
          when String
            resource.strip.start_with?('http') ? [resource] : []
          when Array
            resource
          else
            []
          end
        end
      end
    end
  end
end
