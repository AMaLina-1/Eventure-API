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
            serno:, name:,
            detail:,
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
          location_json = @data['location(座標資訊)']
          address = ''
          if location_json && !location_json.empty?
            begin
              location_data = JSON.parse(location_json)
              address = location_data['address'] || ''
            rescue JSON::ParserError
              address = ''
            end
          end
          normalized = Eventure::Value::Location.normalize_building(address, '台中市')
          Eventure::Value::Location.new(building: normalized, city_name: '台中市')
        end

        def voice
          @data['content(內容)']
        end

        def organizer
          @data['mainunit(主辦單位)']
        end

        def tag_ids
          # @data['subjectid'].split(',').map(&:to_i)
        end

        def tags
          class_name = @data['attribute(活動類型)']
          return [] if class_name.nil? || class_name.empty?

          [Eventure::Entity::Tag.new(tag: class_name)]
        end

        def relate_data
          resource_list = @data['relatedLink(相關連結)']
          return [] unless resource_list

          return [] if resource_list.is_a?(String) && (resource_list.empty? || !resource_list.start_with?('http'))

          resource_list = [resource_list] if resource_list.is_a?(String)
          return [] unless resource_list.is_a?(Array)

          resource_list.map do |relate_item|
            self.class.build_relate_data_entity(relate_item)
          end.compact
        end

        def self.build_relate_data_entity(relate_item)
          return unless relate_item

          url = if relate_item.is_a?(String)
                  relate_item
                else
                  relate_item['relatedLink(相關連結)']
                end

          return unless url&.start_with?('http')

          Eventure::Entity::RelateData.new(
            relatedata_id: nil, relate_title: '', relate_url: url
          )
        end
      end
    end
  end
end
