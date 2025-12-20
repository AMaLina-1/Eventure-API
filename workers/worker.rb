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

    if activities_api_name == 'HCCG'
      puts 'start fetching hccg activities'
      activities = Eventure::Hccg::ActivityMapper.new.find(activities_number).map(&:to_entity)
      Eventure::Repository::Activities.create(activities)
      # cache.set('fetch_hccg', true)
      Eventure::Repository::Status.write_true('hccg')
      puts 'successfully store hccg activities'
    end
  rescue StandardError => e
    puts "Worker error: #{e.message}"
    raise e
  end
end
