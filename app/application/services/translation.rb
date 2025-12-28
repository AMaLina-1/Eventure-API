# frozen_string_literal: true

require 'google/genai'
require 'json'
require 'yaml'
require_relative '../../../config/environment'

module Eventure
  module Service
    # Service for translating text using Gemini LLM
    class Translation
      API_KEY = Eventure::App.config.GEMINI_API_KEY

      def initialize
        @client = Google::Genai::Client.new(api_key: API_KEY)
        @db = Eventure::App.db
      end

      def translate_activity(activity)
        name = activity[:name].to_s.strip
        detail = activity[:detail].to_s.strip
        # location = activity[:location].to_s.strip
        # organizer = activity[:organizer].to_s.strip

        return {} if name.empty? && detail.empty?


        prompt = <<~PROMPT
          Translate the following activity information from Traditional Chinese to English.
          Keep the translation natural and concise.

          Title: #{activity[:name]}
          Detail: #{activity[:detail]}
          Location: #{activity[:location]}
          Organizer: #{activity[:organizer]}

          Return only a JSON object with these fields:
          {
            "name_en": "translated title",
            "detail_en": "translated detail",
            "tag_en": "translated tags",
            "location_en": "translated location",
            "organizer_en": "translated organizer"
          }
        PROMPT

        response = @client.models.generate_content(
          model: 'gemini-2.0-flash',
          contents: prompt
        )

        response_text = response.text.strip

        json_match = response_text.match(/\{.*\}/m)
        if json_match
          JSON.parse(json_match[0])
        else
          {}
        end
      rescue StandardError => e
        puts "Error translating activity #{activity[:serno]}: #{e.message}"
        {}
      end

      def translate_all_activities
        activities = @db[:activities].all
        puts "Translating #{activities.length} activities..."

        success_count = 0
        skipped_count = 0

        activities.each_with_index do |activity, index|
          serno = activity[:serno] || 'UNKNOWN'
          if activity[:name_en] && !activity[:name_en].empty?
            puts "#{index + 1}/#{activities.length} - #{activity[:serno]}: Already translated, skipping"
            skipped_count += 1
            next
          end

          name = activity[:name].to_s.strip
          detail = activity[:detail].to_s.strip
          if name.empty? && detail.empty?
            puts "#{index + 1}/#{activities.length} - #{serno}: skipped (no content to translate)"
            skipped_count += 1
            next
          end

          translations = translate_activity(activity)

          if translations.empty?
            puts "#{index + 1}/#{activities.length} - #{activity[:serno]}: Translation failed"
            next
          end

          @db[:activities].where(activity_id: activity[:activity_id]).update(
            name_en: translations['name_en'],
            detail_en: translations['detail_en'],
            tag_en: translations['tag_en'],
            location_en: translations['location_en'],
            organizer_en: translations['organizer_en']
          )

          success_count += 1
          puts "#{index + 1}/#{activities.length} - #{activity[:serno]}: Translated"

          sleep(0.5)
        end
      end

      def translate_new_activities
        untranslated = @db[:activities].where(Sequel.or(name_en: nil, name_en: '')).all

        if untranslated.empty?
          puts "All activities are already translated!"
          return
        end

        puts "Found #{untranslated.length} untranslated activities"

        success_count = 0

        untranslated.each_with_index do |activity, index|
          translations = translate_activity(activity)

          if translations.empty?
            puts "#{index + 1}/#{untranslated.length} - #{activity[:serno]}: Translation failed"
            next
          end

          @db[:activities].where(activity_id: activity[:activity_id]).update(
            name_en: translations['name_en'],
            detail_en: translations['detail_en'],
            tag_en: translations['tag_en'],
            location_en: translations['location_en'],
            organizer_en: translations['organizer_en']
          )

          success_count += 1
          puts "#{index + 1}/#{untranslated.length} - #{activity[:serno]}: ✓ Translated"

          sleep(0.5)
        end

        puts "\n✓ Successfully translated #{success_count}/#{untranslated.length} activities!"
      end
    end
  end
end

# Run the translator if called directly
if __FILE__ == $PROGRAM_NAME
  translator = Eventure::Service::Translation.new
  translator.translate_all_activities
end