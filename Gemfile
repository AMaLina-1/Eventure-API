# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

gem 'base64'
gem 'yaml'

# Networking
gem 'http', '~> 5.3'

# Testing
group :test do
  gem 'minitest', '~> 5.20'
  gem 'minitest-rg', '~> 5.2'
  gem 'simplecov', '~> 0'
  gem 'vcr', '~> 6'
  gem 'webmock', '~> 3'
end

# Development
group :development do
  gem 'flog'
  gem 'reek'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
end

# Configuration and Utilities
gem 'figaro', '~> 1.0'
gem 'pry'
gem 'rack-test'
gem 'rake'

# PRESENTATION LAYER
gem 'multi_json', '~> 1.15'
gem 'ostruct', '~> 0.0'
gem 'roar', '~> 1.1'

# Validation
gem 'dry-struct', '~> 1.0'
gem 'dry-types', '~> 1.0'

# Web Application
gem 'dry-monads', '~> 1.0'
gem 'dry-transaction'
gem 'dry-validation'
gem 'logger', '~> 1.0'
gem 'puma', '~> 6.4'
gem 'rack-session', '~> 0'
gem 'roda', '~> 3.0'

# Caching
gem 'rack-cache', '~> 1.13'
gem 'redis', '~> 4.8'
gem 'redis-rack-cache', '~> 2.2'

# Database
gem 'hirb'
gem 'sequel', '~> 5.0'

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

group :production do
  gem 'pg', '~> 1.0'
end
