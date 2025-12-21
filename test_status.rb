require_relative 'load_all'

puts "Before:"
puts Eventure::Repository::Status.get_status('hccg')

puts "\nCalling write_true('hccg')..."
result = Eventure::Repository::Status.write_true('hccg')
puts "Result: #{result.inspect}"

puts "\nAfter:"
puts Eventure::Repository::Status.get_status('hccg')

puts "\nDirect database query:"
Eventure::App.db[:status].where(status_name: 'hccg').each do |row|
  puts "#{row[:status_name]} => #{row[:status]}"
end
