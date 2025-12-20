# frozen_string_literal: true

require_relative '../require_app'
require_app

require 'figaro'
require 'shoryuken'

# Shoryuken worker class to clone repos in parallel
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

  shoryuken_options queue: config.QUEUE_URL, auto_delete: true

  def perform(_sqs_msg, request)
    activities_payload = Eventure::Representer::WorkerFetchData.new(OpenStruct.new).from_json(request)
    activities_api_name = activities_payload.api_name
    activities_number = activities_payload.number
    # cache = Eventure::Cache::Client.new(App.config)

    puts "start fetching #{activities_api_name} activities"
    if activities_api_name == 'hccg'
      activities = Eventure::Hccg::ActivityMapper.new.find(activities_number).map(&:to_entity)
    elsif activities_api_name == 'taipei'
      activities = Eventure::Taipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    elsif activities_api_name == 'new_taipei'
      activities = Eventure::NewTaipei::ActivityMapper.new.find(activities_number).map(&:to_entity)
    elsif activities_api_name == 'taichung'
      activities = Eventure::Taichung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    elsif activities_api_name == 'tainan'
      activities = Eventure::Tainan::ActivityMapper.new.find(activities_number).map(&:to_entity)
    elsif activities_api_name == 'kaohsiung'
      activities = Eventure::Kaohsiung::ActivityMapper.new.find(activities_number).map(&:to_entity)
    end

    Eventure::Repository::Activities.create(activities)
    # cache.set('fetch_hccg', true)
    Eventure::Repository::Status.write_true(activities_api_name)
    puts "successfully store #{activities_api_name} activities"
  rescue StandardError => e
    print('other worker error', e)
    raise e
  end
end
