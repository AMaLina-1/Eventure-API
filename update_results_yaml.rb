require 'http'
require 'json'
require 'yaml'
require 'fileutils'
require_relative 'spec/helpers/spec_helper'

def convert_json_to_yaml(json_data, yaml_path)
  parsed_data = JSON.parse(json_data)
  FileUtils.mkdir_p(File.dirname(yaml_path)) unless File.dirname(yaml_path) == '.'
  File.write(yaml_path, parsed_data.to_yaml)
  puts "Converted JSON to YAML at #{yaml_path}"
end

page1 = HTTP.get("https://webopenapi.hccg.gov.tw/v1/Activity?top=#{TOP}")
yaml_path = 'spec/fixtures/results_new.yml'

convert_json_to_yaml(page1.body.to_s, yaml_path)
