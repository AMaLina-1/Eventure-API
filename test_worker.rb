require_relative 'load_all'

# 模擬 activities 為 nil 的情況
activities = nil

begin
  Eventure::Repository::Activities.create(activities)
  puts "No error!"
rescue StandardError => e
  puts "Error caught: #{e.class} - #{e.message}"
end
