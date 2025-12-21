# frozen_string_literal: true

require 'faye'
require_relative 'require_app'
require_app

# ================== One-Time Initialization on Startup ==================
puts 'Initializing application...'
puts 'create status database'
Eventure::Repository::Status.setup!

puts "fetch_api_activities called"
request_id = [Time.now.to_f, Time.now.to_f].hash
result = Eventure::Service::ApiActivities.new.call(total: 100, request_id: request_id, config: Eventure::App.config)
if result.failure?
  failed = Eventure::Representer::HttpResponse.new(result.failure)
  puts "Failed to fetch activities: #{failed.http_status_code}"
else
  puts 'successfully fetched and saved activities'
end

use Faye::RackAdapter, mount: '/faye', timeout: 25
run Eventure::App.freeze.app
