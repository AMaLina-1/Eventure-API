# frozen_string_literal: true

require 'date'

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
          # Tainan API沒有 serno，使用 link 做可重現的雜湊以避免全部寫成同一筆
          raw = @data['link'].to_s
          return '' if raw.empty?

          Digest::SHA1.hexdigest(raw)[0, 16]
        end

        def name
          @data['title']
        end

        def detail
          @data['content']
        end

        # act_date 解析起始時間
        # 例: "2026/02/06 09:00~2026/03/08 17:00"
        # 或: "2026/01/24 15:00~16:30"
        def start_time
          raw = @data['act_date'].to_s.strip
          return DateTime.now.new_offset(0) if raw.empty?

          parts = raw.split('~').map(&:strip)
          start_str = parts[0]
          DateTime.parse(start_str).new_offset(0)
        end

        # act_date 解析結束時間
        def end_time
          raw = @data['act_date'].to_s.strip
          return start_time if raw.empty?

          parts = raw.split('~').map(&:strip)
          start_str = parts[0]

          end_str =
            if parts.length > 1
              right = parts[1]
              if right =~ %r{\d{4}/\d{2}/\d{2}}
                # 右邊已包含日期，例如 "2026/03/08 17:00"
                right
              else
                # 右邊只有時間，例如 "16:30" -> 補上左邊的日期 "2026/01/24 16:30"
                date_part = start_str.split(' ').first
                "#{date_part} #{right}"
              end
            else
              # 沒有 ~，起訖時間相同
              start_str
            end

          DateTime.parse(end_str).new_offset(0)
        end

        def location
          address = @data['address'].to_s
          Eventure::Value::Location.new(building: address, city_name: '台南市')
        end

        def voice
          @data['content']
        end

        def organizer
          # @data['mainunit(主辦單位)']
          ''
        end

        def tag_ids
          # @data['subjectid'].split(',').map(&:to_i)
        end

        def tags
          class_name = @data['category']
          return [] if class_name.nil? || class_name.empty?

          [Eventure::Entity::Tag.new(tag: class_name)]
        end

        def relate_data
          url = @data['link']
          return [] if url.nil? || url.empty?

          [self.class.build_relate_data_entity(url)].compact
        end

        def self.build_relate_data_entity(url)
          return unless url&.start_with?('http')

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
