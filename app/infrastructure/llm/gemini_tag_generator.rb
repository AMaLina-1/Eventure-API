# frozen_string_literal: true

require 'google/genai'
require 'bundler/setup'
require 'json'

require_relative '../../../config/environment'

API_KEY = Eventure::App.config.GEMINI_API_KEY

# Gemini Tag Generator for Activities
class TagGenerator
  def initialize
    @client = Google::Genai::Client.new(api_key: API_KEY)
    @db = Eventure::App.db
  end

  def clean_html(text)
    return '' if text.nil?

    text.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end

  def generate_tags(activity)
    subject = activity[:name].to_s.strip # Fixed: was activity['subject']
    detail = activity[:detail].to_s.strip
    return [] if subject.empty? && detail.empty?

    clean_detail = clean_html(detail)

    # Get existing tags from database
    existing_tags = @db[:tags].select(:tag, :tag_en).all
    existing_tags_list = if existing_tags.empty?
                           'None, create initial tags'
                         else
                           existing_tags.map { |t| "#{t[:tag]} (#{t[:tag_en]})" }.join(', ')
                         end

    prompt = <<~PROMPT
      You are a tag generator for community events and activities in Taiwan.

      Analyze this activity and assign relevant tags from the existing tag list below.
      If absolutely necessary, you may create 1 new tag, but prefer reusing existing tags.

      Activity Title: #{subject}
      Activity Content: #{clean_detail}

      Existing Tags: #{existing_tags_list}

      Requirements:
      1. Assign tags in Traditional Chinese that describe the main topics/themes
      2. Reuse existing tags when possible
      3. Only create a new tag if no existing tag fits well
      4. Use common, reusable tags when possible (e.g., "健康", "教育", "商業", "家庭", "藝術", "運動")
      5. Focus on what users would search for
      6. Keep tags concise and searchable
      7. Do not use location-based tags like city names
      8. Keep total unique tags across all activities under 10-15

      Return ONLY a JSON array of objects with Chinese tag and English translation. Example format:
      [{"tag": "心理健康", "tag_en": "Mental Health"}, {"tag": "健康", "tag_en": "Wellness"}]
    PROMPT

    response = @client.models.generate_content(
      model: 'gemini-2.0-flash',
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ]
    )

    response_text = response.text.strip

    # Extract JSON from response
    json_match = response_text.match(/\[.*\]/m)
    if json_match
      JSON.parse(json_match[0])
    else
      []
    end
  rescue StandardError => e
    puts "Error generating tags for #{activity[:serno]}: #{e.message}"
    []
  end

  def find_or_create_tag(tag_obj)
    tag_name = tag_obj['tag']
    tag_en = tag_obj['tag_en']

    # Use transaction to avoid database locks
    @db.transaction do
      tag = @db[:tags].where(tag: tag_name).first

      if tag
        @db[:tags].where(id: tag[:id]).update(tag_en: tag_en) if tag[:tag_en].nil? || tag[:tag_en].empty?

        tag[:id]
      else
        @db[:tags].insert(tag: tag_name, tag_en: tag_en)
      end
    end
  end

  def link_activity_to_tags(activity_id, tag_ids)
    # Use transaction to avoid locks
    @db.transaction do
      @db[:activities_tags].where(activity_id: activity_id).delete

      tag_ids.each do |tag_id|
        @db[:activities_tags].insert(
          activity_id: activity_id,
          tag_id: tag_id
        )
      end
    end
  end

  def clear_all_tags
    puts 'Clearing all existing tags...'
    @db.transaction do
      @db[:activities_tags].delete
      @db[:tags].delete
    end
    puts 'All old tags cleared!'
  end

  def process_all_activities(clear_existing: true)
    clear_all_tags if clear_existing

    activities = @db[:activities].all
    puts "Loaded #{activities.length} activities from database"

    if activities.first
      puts "Available columns: #{activities.first.keys.inspect}"
      puts "First activity sample: #{activities.first.inspect}"
    end

    success_count = 0
    skipped_count = 0

    activities.each_with_index do |activity, index|
      serno = activity[:serno] || 'UNKNOWN'
      activity_id = activity[:activity_id]

      if activity_id.nil?
        puts "#{index + 1}/#{activities.length} - #{serno}: No activity ID, skipping"
        skipped_count += 1
        next
      end

      generated_tags = generate_tags(activity)

      if generated_tags.empty?
        puts "#{index + 1}/#{activities.length} - #{serno}: No tags generated"
        skipped_count += 1
        next
      end

      tag_display = generated_tags.map { |t| "#{t['tag']} (#{t['tag_en']})" }.join(', ')
      puts "#{index + 1}/#{activities.length} - #{serno}: #{tag_display}"

      tag_ids = generated_tags.map { |tag_obj| find_or_create_tag(tag_obj) }
      link_activity_to_tags(activity_id, tag_ids)
      success_count += 1

      sleep(0.5)
    end

    puts "\n=== Summary ==="
    puts "Successfully tagged: #{success_count}"
    puts "Skipped: #{skipped_count}"
    puts "\n=== All Tags ==="
    @db[:tags].all.each do |tag|
      puts "Tag: #{tag[:tag]} (#{tag[:tag_en]})"
    end
  end
end

# Run the generator
if __FILE__ == $PROGRAM_NAME
  generator = TagGenerator.new
  generator.process_all_activities(clear_existing: true)
end
