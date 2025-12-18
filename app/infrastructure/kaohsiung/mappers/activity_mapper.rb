# frozen_string_literal: true

require 'date'

require_relative '../../../domain/entities/activity'
require_relative '../../../domain/entities/tag'
require_relative '../../../domain/entities/relatedata'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Kaohsiung
    # data mapper: kaohsiung api response -> Activity entity
    class ActivityMapper
      def initialize(gateway_class = Kaohsiung::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new
        @parsed_data = nil
      end

      def find(top)
        raw = @gateway.parsed_json(top)
        # Kaohsiung API returns {Data: [...], ...}
        @parsed_data = raw.is_a?(Array) ? raw : raw['Data']
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
          @data['Id'].to_s
        end

        def name
          @data['Name']
        end

        def detail
          # @data['content']
          ''
        end

        def start_time
          DateTime.strptime(@data['Start'], '%Y/%m/%d %H:%M').new_offset(0)
        end

        def end_time
          DateTime.strptime(@data['End'], '%Y/%m/%d %H:%M').new_offset(0)
        end

        def location
          raw = @data['Add']
          normalized = Eventure::Value::Location.normalize_building(raw, '高雄市')
          Eventure::Value::Location.new(building: normalized, city_name: '高雄市')
        end

        def voice
          # @data['content']
          ''
        end

        def organizer
          @data['Org']
        end

        def tag_ids
          # @data['subjectid'].split(',').map(&:to_i)
        end

        def tags
          # Kaohsiung API doesn't have category tag
          []
        end

        def relate_data
          # url = @data['link']
          # return [] if url.nil? || url.empty?

          # [self.class.build_relate_data_entity(url)].compact
          []
        end

        # def self.build_relate_data_entity(url)
        #   return unless url&.start_with?('http')

        #   Eventure::Entity::RelateData.new(
        #     relatedata_id: nil,
        #     relate_title: '',
        #     relate_url: url
        #   )
        # end
      end
    end
  end
end
