# frozen_string_literal: true

require_relative '../require_app'
require_relative 'fetch_monitor'
require_relative 'job_reporter'
require_app

require 'figaro'
require 'shoryuken'

# Shoryuken worker class to fetch activities in parallel
class Worker
  # Environment variables setup
  Figaro.application = Figaro::Application.new(
    environment: ENV['RACK_ENV'] || 'development',
    path: File.expand_path('config/secrets.yml')
  )
  Figaro.load
  def self.config = Figaro.env

  Shoryuken.sqs_client = Aws::SQS::Client.new(
    access_key_id: config.AWS_ACCESS_KEY_ID,
    secret_access_key: config.AWS_SECRET_ACCESS_KEY,
    region: config.AWS_REGION
  )

  include Shoryuken::Worker

  Shoryuken.sqs_client_receive_message_opts = { wait_time_seconds: 20 }
  shoryuken_options queue: config.QUEUE_URL, auto_delete: true

  def perform(_sqs_msg, request)
    job = FetchApi::JobReporter.new(request, Worker.config)
    # activities_payload = Eventure::Representer::FetchRequest.new(OpenStruct.new).from_json(request)

    # activities_api_name = activities_payload.api_name
    # activities_number = activities_payload.number
    (activities_api_name, activities_number) = split_name_number(request)

    activities = select_activities_api(activities_api_name, activities_number)

    Eventure::Repository::Activities.create(activities)
    mark_success(activities_api_name, job)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    mark_error(activities_api_name, e, 'http', job)
  rescue StandardError => e
    mark_error(activities_api_name, e, 'standard', job)
    # e.set_backtrace([]) if e.respond_to?(:set_backtrace)
    # raise e
  end

  private

  def split_name_number(request)
    activities_payload = Eventure::Representer::FetchRequest.new(OpenStruct.new).from_json(request)

    activities_api_name = activities_payload.api_name
    activities_number = activities_payload.number
    [activities_api_name, activities_number]
  end

  def select_activities_api(api_name, activities_number)
    puts "start fetching #{api_name} activities"
    mappers = {
      'hccg' => Eventure::Hccg::ActivityMapper,
      # 'taipei' => Eventure::Taipei::ActivityMapper,
      'new_taipei' => Eventure::NewTaipei::ActivityMapper,
      'taichung' => Eventure::Taichung::ActivityMapper,
      'tainan' => Eventure::Tainan::ActivityMapper,
      'kaohsiung' => Eventure::Kaohsiung::ActivityMapper
    }

    return [] unless mappers[api_name] # 預設空陣列，避免 nil

    mappers[api_name].new.find(activities_number).map(&:to_entity)
  end

  def mark_error(api_name, error, type, job)
    Eventure::Repository::Status.write_failure(api_name)
    puts "[ERROR] Failed to fetch #{api_name} API: #{error.message}"
    if type == 'http'
      job.report_api_progress(api_name)
    else
      error.set_backtrace([]) if error.respond_to?(:set_backtrace)
      raise error
    end
  end

  def mark_success(api_name, job)
    Eventure::Repository::Status.write_success(api_name)
    puts "Successfully store #{api_name} activities"
    job.report_api_progress(api_name)
  end
end
