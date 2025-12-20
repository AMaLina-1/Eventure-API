require_relative 'load_all'

# 測試序列化
data = OpenStruct.new(api_name: 'hccg', number: 100)
json = Eventure::Representer::WorkerFetchData.new(data).to_json
puts "Serialized JSON:"
puts json

# 測試反序列化
parsed = Eventure::Representer::WorkerFetchData.new(OpenStruct.new).from_json(json)
puts "\nDeserialized:"
puts "api_name: #{parsed.api_name}"
puts "number: #{parsed.number}"
