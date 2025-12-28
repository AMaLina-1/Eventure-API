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
    activities_payload = Eventure::Representer::FetchRequest.new(OpenStruct.new).from_json(request)

    activities_api_name = activities_payload.api_name
    activities_number = activities_payload.number
    # cache = Eventure::Cache::Client.new(App.config)

    puts "start fetching #{activities_api_name} activities"
    # activities = case activities_api_name
    #              when 'hccg'
    #                Eventure::Hccg::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              when 'taipei'
    #                Eventure::Taipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              when 'new_taipei'
    #                Eventure::NewTaipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              when 'taichung'
    #                Eventure::Taichung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              when 'tainan'
    #                Eventure::Tainan::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              when 'kaohsiung'
    #                Eventure::Kaohsiung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    #              end

    activities = select_activities_api(activities_api_name, activities_number)

    Eventure::Repository::Activities.create(activities)
    # cache.set('fetch_hccg', true)
    Eventure::Repository::Status.write_success(activities_api_name)
    puts "successfully store #{activities_api_name} activities"
    job.report_api_progress(activities_api_name)
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    Eventure::Repository::Status.write_failure(activities_api_name)
    puts "ERROR: #{activities_api_name} has errors during connection: #{e.message}"
    job.report_api_progress(activities_api_name)
  rescue StandardError => e
    Eventure::Repository::Status.write_failure(activities_api_name)
    puts "ERROR: #{activities_api_name} API fetch failed: #{e.class} - #{e.message}"
    # puts e.backtrace.join("\n")
    # job.report_api_progress(activities_api_name)
    e.set_backtrace([]) if e.respond_to?(:set_backtrace)
    raise e
  end

  private

  def select_activities_api(api_name, activities_number)
    case api_name
    when 'hccg'
      Eventure::Hccg::ActivityMapper.new.find(activities_number).map(&:to_entity)
    when 'taipei'
      Eventure::Taipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    when 'new_taipei'
      Eventure::NewTaipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    when 'taichung'
      Eventure::Taichung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    when 'tainan'
      Eventure::Tainan::ActivityMapper.new.find(activities_number).map(&:to_entity)
    when 'kaohsiung'
      Eventure::Kaohsiung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    end
  end
end
