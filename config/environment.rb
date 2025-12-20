# frozen_string_literal: true

require 'google/genai'
require 'roda'
require 'yaml'
require 'figaro'
require 'sequel'
require 'rack/session'
require 'rack/cache'
require 'redis-rack-cache'

module Eventure
  # Main application class
  class App < Roda
    plugin :environments

    # Environment variables setup
    Figaro.application = Figaro::Application.new(
      environment:,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    use Rack::Session::Cookie, secret: config.SESSION_SECRET

    configure :development, :test do
      ENV['DATABASE_URL'] = "sqlite://#{config.DB_FILENAME}"
    end

    # Setup Cacheing mechanism
    configure :development do
      use Rack::Cache,
          verbose: true,
          metastore: 'file:_cache/rack/meta',
          entitystore: 'file:_cache/rack/body'
    end

    configure :production do
      use Rack::Cache,
          verbose: true,
          metastore: "#{config.REDISCLOUD_URL}/0/metastore",
          entitystore: "#{config.REDISCLOUD_URL}/0/entitystore"
    end

    # Database Setup
    @db = Sequel.connect(ENV.fetch('DATABASE_URL'), timeout: 3_000)
    def self.db = @db # rubocop:disable Style/TrivialAccessors
  end
end
