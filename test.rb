 require 'redis'
 require 'json'
 redis = Redis.new(url: 'redis://default:qozvisWJRPZZtguH1sKGrqP6hv9mwvhD@redis-13406.c9.us-east-1-4.ec2.cloud.redislabs.com:13406')
 redis.set('soumya', {name: 'Soumya Ray', dept: 'ISS' }.to_json)
 redis.set('leewei', {name: 'Lee-Wei Yang', dept: 'IBSB' }.to_json)
 puts redis.keys
 # => ["leewei", "soumya"]
 me = redis.get('soumya')
 puts me
 # => "{\"name\":\"Soumya Ray\",\"dept\":\"ISS\"}"
 puts JSON.parse(me)
 # => {"name"=>"Soumya Ray", "dept"=>"ISS"}
 redis.keys.each { |key| redis.del(key) }