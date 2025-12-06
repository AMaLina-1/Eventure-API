# frozen_string_literal: true

require_relative '../../hccg/mappers/activity_mapper'
require_relative '../../../domain/values/location'
require_relative '../../../domain/values/activity_date'

module Eventure
  module Repository
    # repository for activities
    class Activities
      # --- 每次都同步（不看 DB 是否為空） ---
      # def self.sync_from?(service, limit: 100)
      #   Array(service.fetch_activities(limit)).each { |entity| db_find_or_create(entity) }
      #   true
      # end

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
        # db_activity = Eventure::Database::ActivityOrm.first(serno: entity.serno)
        # attr_hash = Eventure::Hccg::ActivityMapper.to_attr_hash(entity)
        # if db_activity
        #   db_activity.update(attr_hash.reject { |attr_name, _| attr_name.to_s == 'likes_count' })
        # else
        #   db_activity = Eventure::Database::ActivityOrm.create(
        #     **attr_hash.merge(likes_count: 0).reject { |attr_name, _| attr_name.to_s == 'likes_count' },
        #     likes_count: entity.likes_count
        #   )
        # end
        # db_activity
      end

      def self.build_activity_record(entity)
        Database::ActivityOrm.create(
          serno: entity.serno, name: entity.name, detail: entity.detail,
          start_time: entity.start_time.to_time.utc,
          end_time: entity.end_time.to_time.utc,
          location: entity.location, voice: entity.voice,
          organizer: entity.organizer, likes_count: 0 # db_record.likes_count.to_i
        )
      end

      def self.assign_tags(db_activity, tags)
        # 先移除所有舊的 tag 關聯，避免重複累積
        db_activity.remove_all_tags

        # 重新建立 tag 關聯
        Array(tags).each do |tag|
          tag_orm = find_or_create_tag(tag)
          db_activity.add_tag(tag_orm)
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

        entity
      end

      def self.rebuild_entity_attributes(db_record)
        # db_tags = db_record.tags

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
        Eventure::Value::Location.new(building: location_string)
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

      def self.update_likes(entity)
        db_activity = Database::ActivityOrm.first(serno: entity.serno)
        db_activity.update(likes_count: entity.likes_count)
        # db_activity
      end

      # 交易包起來；若撞到唯一鍵（代表已存在），就改取既有那筆
      # def self.with_unique_retry(serno, &)
      #   Eventure::App.db.transaction(&)
      # rescue Sequel::UniqueConstraintViolation
      #   find_existing_by_serno(serno)
      # end
      # private_class_method :with_unique_retry
    end
  end
end
