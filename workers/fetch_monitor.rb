# frozen_string_literal: true

require_relative '../app/infrastructure/database/repositories/status'

module FetchApi
  # Infrastructure to fetch while yielding progress
  module FetchMonitor
    # 總共有多少個 API 需要 fetch
    TOTAL_APIS = 6
    
    # 每個 API 完成時增加的百分比（100 / 6 ≈ 16.67，四捨五入為 17）
    PERCENT_PER_API = (100.0 / TOTAL_APIS).round

    def self.starting_percent
      '0'
    end

    def self.finished_percent
      '100'
    end

    # 根據已完成的 API 個數計算進度百分比
    # 0 個完成 = 0%, 1 個完成 = 17%, 2 個完成 = 33%, ..., 6 個完成 = 100%
    def self.calculate_completed_apis(completed_count = nil)
      completed_count ||= count_completed_apis
      
      percent = (completed_count * PERCENT_PER_API)
      [percent, 100].min.to_s
    end

    # 計算已完成的 API 個數
    def self.count_completed_apis
      Eventure::Repository::Status::ALL_API.count { |api| Eventure::Repository::Status.get_status(api) == 'true' }
    end

    # 列出還未完成的 API
    def self.remaining_apis
      Eventure::Repository::Status::ALL_API.select { |api| Eventure::Repository::Status.get_status(api) != 'true' }
    end
  end
end