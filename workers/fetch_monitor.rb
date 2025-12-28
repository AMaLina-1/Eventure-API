# frozen_string_literal: true

require_relative '../app/infrastructure/database/repositories/status'

module FetchApi
  # Infrastructure to fetch while yielding progress
  module FetchMonitor
    # TOTAL_APIS = 6
    # PERCENT_PER_API = (100.0 / TOTAL_APIS).round

    def self.starting_percent
      '0'
    end

    def self.finished_percent
      '100'
    end

    # 根據已完成的 API 個數計算進度百分比
    def self.calculate_completed_apis
      percent = ((success_count + failure_count).to_f / (success_count + failure_count + remaining_count) * 100).round
      [percent, 100].min.to_s
    end

    def self.success_count
      Eventure::Repository::Status::ALL_API.count { |api| Eventure::Repository::Status.get_status(api) == 'success' }
    end

    def self.remaining_count
      Eventure::Repository::Status::ALL_API.count { |api| Eventure::Repository::Status.get_status(api) == 'false' }
    end

    def self.failure_count
      Eventure::Repository::Status::ALL_API.count { |api| Eventure::Repository::Status.get_status(api) == 'failure' }
    end
  end
end
