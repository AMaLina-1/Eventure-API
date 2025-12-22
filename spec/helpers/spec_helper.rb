# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'yaml'

require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/rg'

require 'vcr'
require 'webmock'

require_relative '../../require_app'
require_app

require_relative 'database_helper'
require_relative 'vcr_helper'

TOP = 20
CONFIG = YAML.safe_load_file('config/secrets.yml') if File.exist?('config/secrets.yml')
# API_KEY = CONFIG['API_KEY']
CORRECT = YAML.safe_load_file('spec/fixtures/results_new.yml')

CASSETTES_FOLDER = 'spec/fixtures/cassettes'
CASSETTE_FILE = 'hccg_api'
