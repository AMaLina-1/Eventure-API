# frozen_string_literal: true

require_relative 'progress_publisher'
require_relative 'fetch_monitor'

module FetchApi
  # Reports job progress to client
  class JobReporter
    attr_accessor :project

    def initialize(request_json, config)
      fetch_request = Eventure::Representer::FetchRequest
        .new(OpenStruct.new)
        .from_json(request_json)

      @api_name = fetch_request.api_name
      @number = fetch_request.number
      @publisher = ProgressPublisher.new(config, fetch_request.id)
    end

    def report(msg)
      @publisher.publish msg
    end

    def report_progress(percent)
      @publisher.publish percent
    end

    # def report_progress(percent)
    #   @last_percent ||= 0
    #   return if percent.to_i < @last_percent

    #   @last_percent = percent.to_i
    #   @publisher.publish percent
    # end


    # 報告 API 完成進度（根據已完成的 API 個數）
    def report_api_progress(api_name = @api_name)
      percent = FetchApi::FetchMonitor.calculate_completed_apis
      puts "[#{api_name}] Progress: #{percent}% (#{FetchApi::FetchMonitor.count_completed_apis}/#{FetchMonitor::TOTAL_APIS} APIs completed)"
      report_progress(percent)
    end

    def report_each_second(seconds, &operation)
      seconds.times do
        sleep(1)
        report(operation.call)
      end
    end
  end
end