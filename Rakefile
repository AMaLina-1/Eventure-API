# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'
require_relative 'require_app'

CODE = 'app/**/*.rb'
CASSETTE_DIR = 'spec/fixtures/cassettes'

task :default do
  puts 'rake -T'
end

desc 'Generates a 64 by secret for Rack::Session'
task :new_session_secret do
  require 'base64'
  require 'securerandom'
  secret = SecureRandom.random_bytes(64).then { Base64.urlsafe_encode64(it) }
  puts "SESSION_SECRET: #{secret}"
end

desc 'Run all tests'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  # t.pattern = 'spec/tests_acceptance/api_spec.rb'
  # 查看詳細測試輸出: RACK_ENV=test ruby -Ilib:spec spec/XXX.rb -v
  t.warning = false
end

desc 'Keep rerunning tests when files change'
task :respec do
  sh "rerun -c 'rake spec' --ignore 'coverage/*'"
end

desc 'Run web app'
task :run do
  sh 'bundle exec puma -p 9090'
end

desc 'Keep rerunning web app when files change'
task :rerun do
  sh "rerun -c --ignore 'coverage/*' -- bundle exec puma"
end

namespace :vcr do
  desc 'Delete all VCR cassette files'
  task :wipe do
    if Dir.exist?(CASSETTE_DIR)
      files = Dir.glob("#{CASSETTE_DIR}/*.yml")
      if files.empty?
        puts 'No cassettes found'
      else
        FileUtils.rm_rf(files)
        puts 'Cassettes deleted'
      end
    else
      puts 'No cassette directory found'
    end
  end
end

namespace :quality do
  desc 'Run all static-analysis quality checks'
  task all: %i[rubocop reek flog]

  desc 'Code style linter'
  task :rubocop do
    sh 'rubocop'
  end

  desc 'Code smell detector'
  task :reek do
    sh 'reek'
  end

  desc 'Complexity analysis'
  task :flog do
    sh "flog #{CODE}"
  end
end

# rubocop:disable Metrics/BlockLength
namespace :db do
  task :config do
    require 'sequel'
    require_relative 'config/environment' # load config info
    require_relative 'spec/helpers/database_helper'

    def app = Eventure::App
  end

  desc 'Run migrations'
  task migrate: :config do
    Sequel.extension :migration
    puts "Migrating #{app.environment} database to latest"
    Sequel::Migrator.run(app.db, 'db/migrations')
  end

  desc 'Wipe records from all tables'
  task wipe: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    require_app(%w[models infrastructure])
    DatabaseHelper.wipe_database
  end

  desc 'Delete dev or test database file (set correct RACK_ENV)'
  task drop: :config do
    if app.environment == :production
      puts 'Do not damage production database!'
      return
    end

    FileUtils.rm(Eventure::App.config.DB_FILENAME)
    puts "Deleted #{Eventure::App.config.DB_FILENAME}"
  end
end
# rubocop:enable Metrics/BlockLength

desc 'Run application console'
task :console do
  sh 'pry -r ./load_all.rb'
end

namespace :cache do
  task :config do
    require_relative 'config/environment' # load config info
    require_relative 'app/infrastructure/cache/redis_cache'
    @api = Eventure::App
  end

  desc 'Directory listing of local dev cache'
  namespace :list do
    desc 'Lists development cache'
    task :dev do
      puts 'Lists development cache'
      list = `ls _cache/rack/meta`
      puts 'No local cache found' if list.empty?
      puts list
    end

    desc 'Lists production cache'
    task production: :config do
      puts 'Finding production cache'
      keys = Eventure::Cache::Client.new(@api.config).keys
      puts 'No keys found' if keys.none?
      keys.each { |key| puts "Key: #{key}" }
    end
  end

  namespace :wipe do
    desc 'Delete development cache'
    task :dev do
      puts 'Deleting development cache'
      sh 'rm -rf _cache/*'
    end

    desc 'Delete production cache'
    task production: :config do
      print 'Are you sure you wish to wipe the production cache? (y/n) '
      if $stdin.gets.chomp.downcase == 'y'
        puts 'Deleting production cache'
        wiped = Eventure::Cache::Client.new(@api.config).wipe
        wiped.each { |key| puts "Wiped: #{key}" }
      end
    end
  end
end

namespace :queues do
  task :config do
    require 'aws-sdk-sqs'
    require_relative 'config/environment' # load config info
    @api = Eventure::App
    @sqs = Aws::SQS::Client.new(
      access_key_id: @api.config.AWS_ACCESS_KEY_ID,
      secret_access_key: @api.config.AWS_SECRET_ACCESS_KEY,
      region: @api.config.AWS_REGION
    )
    @q_name = @api.config.QUEUE
    @q_url = @sqs.get_queue_url(queue_name: @q_name).queue_url

    puts "Environment: #{@api.environment}"
  end

  desc 'Create SQS queue for worker'
  task :create => :config do
    @sqs.create_queue(queue_name: @q_name)

    puts 'Queue created:'
    puts "  Name: #{@q_name}"
    puts "  Region: #{@api.config.AWS_REGION}"
    puts "  URL: #{@q_url}"
  rescue StandardError => e
    puts "Error creating queue: #{e}"
  end

  desc 'Report status of queue for worker'
  task :status => :config do
    puts 'Queue info:'
    puts "  Name: #{@q_name}"
    puts "  Region: #{@api.config.AWS_REGION}"
    puts "  URL: #{@q_url}"
  rescue StandardError => e
    puts "Error finding queue: #{e}"
  end

  desc 'Purge messages in SQS queue for worker'
  task :purge => :config do
    @sqs.purge_queue(queue_url: @q_url)
    puts "Queue #{@q_name} purged"
  rescue StandardError => e
    puts "Error purging queue: #{e}"
  end
end

namespace :worker do
  namespace :run do
    desc 'Run the background cloning worker in development mode'
    task :dev => :config do
      sh 'RACK_ENV=development bundle exec shoryuken -r ./workers/worker.rb -C ./workers/shoryuken_dev.yml'
    end

    desc 'Run the background cloning worker in testing mode'
    task :test => :config do
      sh 'RACK_ENV=test bundle exec shoryuken -r ./workers/worker.rb -C ./workers/shoryuken_test.yml'
    end

    desc 'Run the background cloning worker in production mode'
    task :production => :config do
      sh 'RACK_ENV=production bundle exec shoryuken -r ./workers/worker.rb -C ./workers/shoryuken.yml'
    end
  end
end

namespace :tags do
  desc 'Generate AI tags for all activities'
  task :generate do
    require_relative 'app/infrastructure/llm/gemini_tag_generator'
    
    puts "WARNING: This will REPLACE all existing tags with AI-generated ones."
    puts "Press Enter to continue, or Ctrl+C to cancel..."
    $stdin.gets
    
    generator = TagGenerator.new
    generator.process_all_activities(clear_existing: true)
  end

  desc 'Generate AI tags without clearing existing ones (append only)'
  task :append do
    require_relative 'app/infrastructure/llm/gemini_tag_generator'
    
    generator = TagGenerator.new
    generator.process_all_activities(clear_existing: false)
  end
end

namespace :translation do
  desc 'Translate all activities (LOCAL ONLY - costs money!)'
  task :translate do
    require_relative 'app/application/services/translation'
    
    translator = Eventure::Service::Translation.new
    translator.translate_all_activities
  end
  
  desc 'Translate only new activities (LOCAL ONLY)'
  task :new do
    require_relative 'app/application/services/translation'
    
    translator = Eventure::Service::Translation.new
    translator.translate_new_activities
  end
end

# Add this to your existing Rakefile (inside the namespace :db block)

namespace :db do
  desc 'Export local SQLite data and sync to Heroku PostgreSQL'
  task sync_to_heroku: :config do  # Add :config dependency
    puts "=" * 70
    puts "SYNCING LOCAL DATABASE TO HEROKU"
    puts "=" * 70
    
    # Create tmp directory if it doesn't exist
    FileUtils.mkdir_p('tmp')
    
    # 1. Export from local SQLite
    puts "\n📤 Step 1: Exporting from local SQLite..."
    local_db = app.db  # Use app.db instead of Eventure::App
    
    # Export activities
    activities = local_db[:activities].all
    puts "   Exported #{activities.length} activities"
    
    # Export tags
    tags = local_db[:tags].all
    puts "   Exported #{tags.length} tags"
    
    # Export activities_tags relationships
    activities_tags = local_db[:activities_tags].all
    puts "   Exported #{activities_tags.length} tag relationships"
    
    # Save to JSON files for transfer
    File.write('tmp/activities.json', activities.to_json)
    File.write('tmp/tags.json', tags.to_json)
    File.write('tmp/activities_tags.json', activities_tags.to_json)
    
    puts "\n✅ Data exported to tmp/ folder"
    puts "\n📋 Next steps:"
    puts "1. Push these files to Heroku:"
    puts "   git add tmp/*.json"
    puts "   git commit -m 'Add exported data'"
    puts "   git push heroku main"
    puts ""
    puts "2. Run import on Heroku:"
    puts "   heroku run rake db:import_from_json"
    puts "=" * 70
  end
  
  desc 'Import JSON data into database (run on Heroku)'
  task import_from_json: :config do  # Add :config dependency
    puts "=" * 70
    puts "IMPORTING DATA FROM JSON FILES"
    puts "=" * 70
    
    db = app.db
    
    # Check if files exist
    unless File.exist?('tmp/tags.json')
      puts "❌ Error: tmp/tags.json not found"
      puts "Make sure you've pushed the JSON files to Heroku"
      exit 1
    end
    
    # Clear existing data
    puts "\n🗑️  Clearing existing data..."
    db[:activities_tags].delete
    db[:tags].delete
    db[:activities].delete
    
    # Import tags first (needed for foreign keys)
    puts "\n📥 Importing tags..."
    tags_data = JSON.parse(File.read('tmp/tags.json'))
    tags_data.each do |tag|
      db[:tags].insert(tag)
    end
    puts "   ✅ Imported #{tags_data.length} tags"
    
    # Import activities
    puts "\n📥 Importing activities..."
    activities_data = JSON.parse(File.read('tmp/activities.json'))
    activities_data.each do |activity|
      db[:activities].insert(activity)
    end
    puts "   ✅ Imported #{activities_data.length} activities"
    
    # Import relationships
    puts "\n📥 Importing tag relationships..."
    relationships_data = JSON.parse(File.read('tmp/activities_tags.json'))
    relationships_data.each do |rel|
      db[:activities_tags].insert(rel)
    end
    puts "   ✅ Imported #{relationships_data.length} relationships"
    
    puts "\n" + "=" * 70
    puts "✅ DATA IMPORT COMPLETE!"
    puts "=" * 70
  end
end