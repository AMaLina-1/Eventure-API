# frozen_string_literal: true

require_relative '../../hccg/mappers/activity_mapper'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Repository
    # repository for activities
    class Activities
      def self.all
        Database::ActivityOrm.all.map { |db_activity| rebuild_entity(db_activity) }
      end

      def self.find_serno(serno)
        db_record = Database::ActivityOrm.first(serno:)
        rebuild_entity(db_record)
      end

      def self.create(entities)
        Array(entities).map do |entity|
          db_activity = find_or_create_activity(entity)
          assign_tags(db_activity, entity.tags)
          assign_relate_data(db_activity, entity.relate_data)
          rebuild_entity(db_activity)
        end
      end

      def self.find_or_create_activity(entity)
        attr_hash = Eventure::Hccg::ActivityMapper.to_attr_hash(entity)
        filtered_attrs = attr_hash.reject { |attr_name, _| attr_name.to_s == 'likes_count' }

        Eventure::Database::ActivityOrm.first(serno: entity.serno)&.tap do |activity|
          activity.update(filtered_attrs)
        end || Eventure::Database::ActivityOrm.create(**attr_hash, likes_count: entity.likes_count || 0)
      end

      def self.build_activity_record(entity)
        Database::ActivityOrm.create(
          serno: entity.serno, name: entity.name, detail: entity.detail,
          start_time: entity.start_time.to_time.utc,
          end_time: entity.end_time.to_time.utc,
          location: entity.location, voice: entity.voice,
          organizer: entity.organizer, likes_count: 0
        )
      end

      def self.assign_tags(db_activity, tags)
        # Use database transaction with retry logic for SQLite locks
        retry_count = 0
        max_retries = 3

        begin
          Eventure::App.db.transaction do
            # Remove all old tags
            db_activity.remove_all_tags

            # Add new tags
            Array(tags).each do |tag|
              tag_orm = find_or_create_tag(tag)
              db_activity.add_tag(tag_orm)
            end
          end
        rescue Sequel::DatabaseError => e
          if e.message.include?('database is locked') && retry_count < max_retries
            retry_count += 1
            sleep(0.5 * retry_count) # Exponential backoff
            retry
          else
            raise
          end
        end
      end

      def self.find_or_create_tag(tag)
        tag_name = tag.is_a?(Eventure::Entity::Tag) ? tag.tag : tag
        Database::TagOrm.first(tag: tag_name) || Database::TagOrm.create(tag: tag_name)
      end

      def self.assign_relate_data(db_activity, relate_data)
        return if relate_data.to_a.empty?

        db_activity.reload

        Array(relate_data).each do |relate|
          db_relate = Relatedata.find_or_create(relate)
          db_activity.add_relatedatum(db_relate) unless db_activity.relatedata.include?(db_relate)
        end
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        entity = Eventure::Entity::Activity.new(rebuild_entity_attributes(db_record))
        entity.instance_variable_set(:@likes_count, db_record.likes_count.to_i)

        # Add English field accessors to the entity
        entity.instance_variable_set(:@name_en, db_record.name_en)
        entity.instance_variable_set(:@detail_en, db_record.detail_en)
        entity.instance_variable_set(:@location_en, db_record.location_en)
        entity.instance_variable_set(:@organizer_en, db_record.organizer_en)

        # Define reader methods for English fields
        entity.define_singleton_method(:name_en) { @name_en }
        entity.define_singleton_method(:detail_en) { @detail_en }
        entity.define_singleton_method(:location_en) { @location_en }
        entity.define_singleton_method(:organizer_en) { @organizer_en }

        entity
      end

      def self.rebuild_entity_attributes(db_record)
        { **base_attributes(db_record), **time_relate_attributes(db_record, db_record.tags) }
      end

      def self.base_attributes(db_record)
        {
          serno: db_record.serno, name: db_record.name, detail: db_record.detail,
          voice: db_record.voice, organizer: db_record.organizer,
          location: rebuild_location(db_record.location)
        }
      end

      def self.time_relate_attributes(db_record, db_record_tags)
        {
          activity_date: Eventure::Value::ActivityDate.new(
            start_time: build_utc_datetime(db_record.start_time),
            end_time: build_utc_datetime(db_record.end_time)
          ),
          tags: rebuild_tags(db_record_tags),
          relate_data: rebuild_relate_data(db_record.relatedata)
        }
      end

      def self.rebuild_location(location_string)
        Eventure::Value::Location.new(
          building: location_string,
          city_name: parse_city_from_building(location_string)
        )
      end

      def self.build_utc_datetime(time)
        Time.utc(
          time.year, time.month, time.day, time.hour, time.min, time.sec
        ).to_datetime
      end

      def self.rebuild_tags(db_tags)
        db_tags.map { |tag| Eventure::Entity::Tag.new(tag: tag.tag) }
      end

      def self.rebuild_relate_data(db_relatedata)
        db_relatedata.map { |rel| Relatedata.rebuild_entity(rel) }
      end

      def self.parse_city_from_building(building)
        return nil if building.to_s.empty?

        %w[新竹市 台北市 新北市 台中市 台南市 高雄市].find { |name| building.include?(name) }
      end

      def self.update_likes(entity)
        db_activity = Database::ActivityOrm.first(serno: entity.serno)
        db_activity.update(likes_count: entity.likes_count)
      end
    end
  end
end
