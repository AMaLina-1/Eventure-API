# frozen_string_literal: true

require 'date'
require 'digest/sha1'

require_relative '../../../domain/entities/activity'
require_relative '../../../domain/entities/tag'
require_relative '../../../domain/entities/relatedata'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Tainan
    # data mapper: tainan api response -> Activity entity
    class ActivityMapper
      def initialize(gateway_class = Tainan::Api)
        @gateway_class = gateway_class
        @gateway = @gateway_class.new
        @parsed_data = nil
      end

      def find(top)
        raw = @gateway.parsed_json(top)
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
        CITY = '台南市'

        def initialize(data)
          @data = data
        end

        def to_entity
          Eventure::Entity::Activity.new(
            serno:, name:, detail:,
            activity_date: activity_date,
            location:, voice:, organizer:, tags:,
            relate_data:
          )
        end

        def serno
          self.class.build_serno(@data['link'])
        end

        def name
          @data['title']
        end

        def detail
          @data['content']
        end

        def activity_date
          Eventure::Value::ActivityDate.new(
            start_time: start_time,
            end_time: end_time
          )
        end

        def start_time
          self.class.parse_start_time(@data['act_date'])
        end

        def end_time
          self.class.parse_end_time(@data['act_date'])
        end

        def location
          address = @data['address'].to_s
          normalized = Eventure::Value::Location.normalize_building(address, CITY)
          Eventure::Value::Location.new(building: normalized, city_name: CITY)
        end

        def voice
          @data['content']
        end

        def organizer
          ''
        end

        def tags
          self.class.build_tags(@data['category'])
        end

        def relate_data
          self.class.build_relate_data(@data['link'])
        end

        def self.build_serno(link)
          raw = link.to_s.strip
          return '' if raw.empty?

          Digest::SHA1.hexdigest(raw)[0, 16]
        end

        def self.parse_start_time(raw)
          str = raw.to_s.strip
          return DateTime.now.new_offset(0) if str.empty?

          start_str = str.split('~').first.strip
          DateTime.parse(start_str).new_offset(0)
        end

        def self.parse_end_time(raw)
          parts = split_parts(raw)
          start_str = parts.first
          end_str = build_end_str(parts, start_str)
          DateTime.parse(end_str).new_offset(0)
        end

        def self.build_end_str(parts, start_str)
          return start_str if parts.length < 2

          right = parts[1]
          return right if right.match?(%r{\d{4}/\d{2}/\d{2}})

          "#{start_str.split.first} #{right}"
        end

        def self.split_parts(raw)
          str = raw.to_s.strip
          return [parse_start_time(raw).strftime('%Y/%m/%d %H:%M')] if str.empty?

          str.split('~').map(&:strip)
        end

        def self.build_tags(category)
          name = category.to_s.strip
          return [] if name.empty?

          [Eventure::Entity::Tag.new(tag: name)]
        end

        def self.build_relate_data(link)
          url = link.to_s.strip
          return [] unless url.start_with?('http')

          [build_relate_data_entity(url)]
        end

        def self.build_relate_data_entity(url)
          Eventure::Entity::RelateData.new(
            relatedata_id: nil,
            relate_title: '',
            relate_url: url
          )
        end
      end
    end
  end
end