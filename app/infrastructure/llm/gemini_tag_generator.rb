# frozen_string_literal: true

require 'google/genai'
require 'yaml'
require 'json'

require_relative '../../../config/environment'

API_KEY = Eventure::App.config.GEMINI_API_KEY
YAML_FILE = 'spec/fixtures/results.yml'

class TagGenerator
  def initialize
    @client = Google::Genai::Client.new(api_key: API_KEY)
    @db = Eventure::App.db
  end

  def clean_html(text)
    # Remove HTML tags for better processing
    text.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end

  def generate_tags(activity)
    clean_detail = clean_html(activity['detailcontent'])
    
    prompt = <<~PROMPT
      You are a tag generator for community events and activities in Hsinchu City, Taiwan.
      
      Analyze this activity and generate 3-5 relevant topic-based tags.
      
      Activity Title: #{activity['subject']}
      Activity Description: #{clean_detail[0..500]}
      Location: #{activity['activityplace']}
      
      Requirements:
      1. Generate 3-5 tags that describe the main topics/themes
      2. Use common, reusable tags when possible (e.g., "Health", "Education", "Business", "Family", "Arts", "Sports")
      3. Use Title Case for tags (e.g., "Mental Health", "Job Training")
      4. If the activity is clearly free or paid, include a "Free" or "Paid" tag
      5. Focus on what users would search for
      6. Keep tags concise and searchable
      
      Return ONLY a JSON array of tags, nothing else. Example format:
      ["Mental Health", "Community", "Support", "Free"]
    PROMPT
    
    response = @client.models.generate_content(
      model: "gemini-2.0-flash",
      contents: prompt
    )
    
    response_text = response.text.strip
    
    # Extract JSON from response
    json_match = response_text.match(/\[.*\]/m)
    if json_match
      JSON.parse(json_match[0])
    else
      []
    end
  rescue => e
    puts "Error generating tags for #{activity['serno']}: #{e.message}"
    []
  end

  def find_or_create_tag(tag_name)
    # Find existing tag or create new one
    tag = @db[:tags].where(tag: tag_name).first
    
    if tag
      tag[:id]
    else
      @db[:tags].insert(tag: tag_name)
    end
  end

  def link_activity_to_tags(activity_id, tag_ids)
    # Remove existing tag relationships for this activity
    @db[:activities_tags].where(activity_id: activity_id).delete
    
    # Create new relationships
    tag_ids.each do |tag_id|
      @db[:activities_tags].insert(
        activity_id: activity_id,
        tag_id: tag_id
      )
    end
  end

  def clear_all_tags
    puts "Clearing all existing tags..."
    @db[:activities_tags].delete
    @db[:tags].delete
    puts "All old tags cleared!"
  end

  def process_all_activities(clear_existing: true)
    # Clear existing tags if requested
    clear_all_tags if clear_existing
    
    # Load activities from YAML
    activities = YAML.load_file(YAML_FILE)
    puts "Loaded #{activities.length} activities from YAML"
    
    success_count = 0
    all_generated_tags = []
    
    activities.each_with_index do |activity, index|
      serno = activity['serno']
      
      # Find the activity in database
      db_activity = @db[:activities].where(serno: serno).first
      unless db_activity
        puts " Not found in database, skipping"
        next
      end
      
      activity_id = db_activity[:activity_id]
      
      # Generate tags
      generated_tags = generate_tags(activity)
      
      if generated_tags.empty?
        puts "No tags generated"
        next
      end
      
      # Track all generated tags
      all_generated_tags.concat(generated_tags)
      
      # Insert tags and create relationships
      tag_ids = generated_tags.map { |tag_name| find_or_create_tag(tag_name) }
      link_activity_to_tags(activity_id, tag_ids)
      success_count += 1
      
      sleep(0.5)
    end
    puts "All activities have been tagged!"
  end
end
