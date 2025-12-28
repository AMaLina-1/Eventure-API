# frozen_string_literal: true

module Eventure
  module Repository
    # repository for status
    class Status
      ALL_API = %w[hccg new_taipei taichung tainan kaohsiung].freeze
      TOTAL_APIS = ALL_API.size

      def self.db
        Eventure::App.db
      end

      def self.table
        db[:status]
      end

      # 程式啟動時呼叫：確保資料存在，並 reset 為 false
      def self.setup!
        ALL_API.each do |api_name|
          row = table.where(status_name: api_name)

          if row.empty?
            table.insert(status_name: api_name, status: 'false')
          else
            row.update(status: 'false')
          end
        end
      end

      # 將某 API 設為 success
      def self.write_success(api_name)
        table.where(status_name: api_name).update(status: 'success')
      end

      # 將某 API 設為 failure
      def self.write_failure(api_name)
        table.where(status_name: api_name).update(status: 'failure')
      end

      # 取得狀態（回傳 true / false / nil）
      def self.get_status(api_name)
        table.where(status_name: api_name).get(:status)
      end
    end
  end
end
