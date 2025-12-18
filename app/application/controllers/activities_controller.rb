# frozen_string_literal: true

require 'date'
require_relative '../../domain/values/filter'
require_relative '../../domain/entities/user_temp'

module Eventure
  module Services
    # Service for activities
    class ActivityService
      def initialize
        @hccg_mapper = Eventure::Hccg::ActivityMapper.new
        @taipei_mapper = Eventure::Taipei::ActivityMapper.new
        @new_taipei_mapper = Eventure::NewTaipei::ActivityMapper.new
        @taichung_mapper = Eventure::Taichung::ActivityMapper.new
        @tainan_mapper = Eventure::Tainan::ActivityMapper.new
        @kaohsiung_mapper = Eventure::Kaohsiung::ActivityMapper.new
      end

      def fetch_activities(limit = 100)
        hccg_activities = fetch_hccg_activities(limit)
        taipei_activities = fetch_taipei_activities(limit)
        new_taipei_activities = fetch_new_taipei_activities(limit)
        taichung_activities = fetch_taichung_activities(limit)
        tainan_activities = fetch_tainan_activities(limit)
        kaohsiung_activities = fetch_kaohsiung_activities(limit)
        hccg_activities + taipei_activities + new_taipei_activities + taichung_activities + tainan_activities + kaohsiung_activities
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

      def fetch_hccg_activities(limit)
        @hccg_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch HCCG activities: #{e.message}"
        []
      end

      def fetch_taipei_activities(limit)
        @taipei_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taipei activities: #{e.message}"
        []
      end

      def fetch_new_taipei_activities(limit)
        @new_taipei_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch New Taipei activities: #{e.message}"
        []
      end

      def fetch_taichung_activities(limit)
        @taichung_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch Taichung activities: #{e.message}"
        []
      end

      def fetch_tainan_activities(limit)
        @tainan_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch Tainan activities: #{e.message}"
        []
      end

      def fetch_kaohsiung_activities(limit)
        @kaohsiung_mapper.find(limit).map(&:to_entity)
      rescue StandardError => e
        puts "Warning: Failed to fetch Kaohsiung activities: #{e.message}"
        []
      end

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
