# frozen_string_literal: true

require 'date'

require_relative '../../../domain/entities/activity'
require_relative '../../../domain/entities/tag'
require_relative '../../../domain/entities/relatedata'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Hccg
    # data mapper: hccg api response -> Activity entity
    class ActivityMapper
      def initialize(gateway_class = Hccg::Api)
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
          @data['serno'].to_s
        end

        def name
          @data['subject']
        end

        def detail
          @data['detailcontent']
        end

        def start_time
          DateTime.strptime(@data['activitysdate'], '%Y%m%d%H%M').new_offset(0)
        end

        def end_time
          DateTime.strptime(@data['activityedate'], '%Y%m%d%H%M').new_offset(0)
        end

        def location
          Eventure::Value::Location.new(building: @data['activityplace'])
        end

        def voice
          @data['voice']
        end

        def organizer
          @data['hostunit']
        end

        def tags
          if @data['subjectclass']
            tag_texts = @data['subjectclass'].split(',')
            tag_texts.map do |tag_text|
              Eventure::Entity::Tag.new(tag: tag_text.split(']')[1])
            end
          elsif @data[:activity_id]
            load_tags_from_db(@data[:activity_id])
          else
            []
          end
        end

        def relate_data
          resource_list = @data['resourcedatalist']
          return [] if resource_list.empty?

          resource_list.map do |relate_item|
            self.class.build_relate_data_entity(relate_item)
          end.compact
        end

        def self.build_relate_data_entity(relate_item)
          return unless relate_item

          Eventure::Entity::RelateData.new(
            relatedata_id: nil,
            relate_title: relate_item['relatename'],
            relate_url: relate_item['relateurl']
          )
        end

        private
        def load_tags_from_db(activity_id)
          db = Eventure::App.db
          tag_rows = db[:activities_tags]
                    .join(:tags, id: :tag_id)
                    .where(activity_id: activity_id)
                    .select(:tag)
                    .all
          tag_rows.map do |tag_row|
            Eventure::Entity::Tag.new(tag: tag_row[:tag])
          end
        end
      end
    end
  end
end
