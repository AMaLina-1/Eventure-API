# frozen_string_literal: true

require 'date'

require_relative '../../../domain/entities/activity'
require_relative '../../../domain/entities/tag'
require_relative '../../../domain/entities/relatedata'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module NewTaipei
    # data mapper: new taipei api response -> Activity entity
    class ActivityMapper
      def initialize(gateway_class = NewTaipei::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new
        @parsed_data = nil
      end

      def find(top)
        @parsed_data = @gateway.parsed_json(top)
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
          @data['id'].to_s
        end

        def name
          @data['title']
        end

        def detail
          @data['description']
        end

        def start_time
          date = Date.strptime(@data['activeDate'], '%m/%d/%Y')
          date.to_datetime.new_offset(0)
        end

        # end_time -> activeEndDate
        def end_time
          raw = @data['activeEndDate']
          return start_time if raw.nil? || raw.empty?

          date = Date.strptime(raw, '%m/%d/%Y')
          date.to_datetime.new_offset(0)
        end

        def location
          Eventure::Value::Location.new(building: @data['address'])
        end

        def voice
          @data['description']
        end

        def organizer
          @data['author']
        end

        def tags
          class_name = @data['className']
          return [] if class_name.nil? || class_name.empty?

          [Eventure::Entity::Tag.new(tag: class_name)]
        end

        def relate_data
          url = @data['aboutUrl']
          return [] if url.nil? || url.empty?

          resource_list = [url]

          resource_list.map do |relate_item|
            self.class.build_relate_data_entity(relate_item)
          end.compact
        end

        def self.build_relate_data_entity(relate_item)
          return unless relate_item

          Eventure::Entity::RelateData.new(
            relatedata_id: nil,
            relate_title: '',
            relate_url: relate_item
          )
        end
      end
    end
  end
end
