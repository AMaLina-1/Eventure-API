# redis_check.rb
require 'redis'

redis_url = 'redis://default:qozvisWJRPZZtguH1sKGrqP6hv9mwvhD@redis-13406.c9.us-east-1-4.ec2.cloud.redislabs.com:13406' # 'redis://:<password>@redis-13406.c9.us-east-1-4.ec2.cloud.redislabs.com:13406/0'

begin
  redis = Redis.new(url: redis_url)

  # 測試連線
  pong = redis.ping
  if pong == "PONG"
    puts "✅ Redis is reachable and responding (PING -> #{pong})"
  else
    puts "⚠️ Redis responded unexpectedly: #{pong.inspect}"
  end
rescue SocketError => e
  puts "❌ Cannot resolve Redis host: #{e.message}"
rescue Redis::CannotConnectError => e
  puts "❌ Cannot connect to Redis: #{e.message}"
rescue Redis::CommandError => e
  puts "❌ Redis command error: #{e.message}"
rescue StandardError => e
  puts "❌ Other error: #{e.class} - #{e.message}"
end
