# frozen_string_literal: true

require_relative '../app/infrastructure/database/repositories/status'

module FetchApi
  # Infrastructure to fetch while yielding progress
  module FetchMonitor
    TOTAL_APIS = 6
    # PERCENT_PER_API = (100.0 / TOTAL_APIS).round

    def self.starting_percent
      '0'
    end

    def self.finished_percent
      '100'
    end

    # 根據已完成的 API 個數計算進度百分比
    def self.calculate_completed_apis  # (completed_count = nil)
      # completed_count ||= count_completed_apis
      # percent = (completed_count * PERCENT_PER_API)
      percent = (count_completed_apis.to_f / (count_completed_apis + remaining_apis.count) * 100).round
      [percent, 100].min.to_s
    end

    # 計算已完成的 API 個數
    def self.count_completed_apis
      Eventure::Repository::Status::ALL_API.count { |api| Eventure::Repository::Status.get_status(api) == 'success' }
    end

    # 列出還未完成的 API
    def self.remaining_apis
      Eventure::Repository::Status::ALL_API.select { |api| Eventure::Repository::Status.get_status(api) == 'false' }
    end

    def self.failed_apis
      Eventure::Repository::Status::ALL_API.select { |api| Eventure::Repository::Status.get_status(api) == 'failure' }
    end
  end
end