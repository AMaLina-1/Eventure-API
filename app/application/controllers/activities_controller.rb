# frozen_string_literal: true

require 'date'
require_relative '../../domain/values/filter'
require_relative '../../domain/entities/user_temp'

module Eventure
  module Services
    # Service for activities
    class ActivityService
      def initialize
        @mapper = Eventure::Hccg::ActivityMapper.new
      end

      def fetch_activities(limit = 100)
        @mapper.find(limit).map(&:to_entity)
      end

      def save_activities(top)
        entities = fetch_activities(top)
        Repository::For.entity(entities.first).create(entities)
      end

      def search(top, user)
        filter = user.to_filter
        save_activities(top).select { |activity| filter.match_filter?(activity) }
      end

      private

      # :reek:UtilityFunction
      def parse_date_range(start_raw, end_raw)
        parts = [start_raw, end_raw].map { |date| date.to_s.strip }
        return [] if parts.any?(&:empty?) # 只要有一邊沒填 → 不啟用日期篩選

        [Date.strptime(parts[0], '%Y-%m-%d'),
         Date.strptime(parts[1], '%Y-%m-%d')] # 兩邊都有 → 轉成 Date[]
      rescue ArgumentError
        [] # 格式錯誤也視為沒選
      end
    end
  end
end
