# frozen_string_literal: true

module Eventure
  module Repository
    # repository for tags
    class Tags
      def self.all
        Database::TagOrm.all.map { |db_tag| rebuild_entity(db_tag) }
      end

      def self.find_or_create(entity)
        tag_value = entity.is_a?(Entity::Tag) ? entity.tag : entity
        db_record = Database::TagOrm.first(tag: tag_value) ||
                    Database::TagOrm.create(tag: tag_value)
        rebuild_entity(db_record)
      end

      def self.rebuild_entity(db_record)
        return nil unless db_record

        Eventure::Entity::Tag.new(tag: db_record.tag)
      end
    end
  end
end
