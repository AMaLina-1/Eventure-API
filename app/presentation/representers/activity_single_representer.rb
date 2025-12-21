# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module Eventure
  module Representer
    # Representer for a single activity
    class ActivitySingle < Roar::Decorator
      include Roar::JSON

      property :serno
      property :name, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        if lang == 'en' && respond_to?(:name_en) && name_en &&  !name_en.empty?
          name_en
        else
          name
        end
      }
      property :location
      property :city, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        if lang == 'en' && respond_to?(:location_en) && location_en &&  !location_en.empty?
          location_en
        else
          city
        end
      }
      property :building
      property :detail, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        if lang == 'en' && respond_to?(:detail_en) && detail_en &&  !detail_en.empty?
          detail_en
        else
          detail
        end
      }
      property :organizer, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        if lang == 'en' && respond_to?(:organizer_en) && organizer_en &&  !organizer_en.empty?
          organizer_en
        else
          organizer
        end
      }
      property :voice
      property :tag, getter: lambda { |args|
        lang = args[:user_options]&.dig(:language) || 'zh-TW'
        Array(tags).map do |t|
          if lang == 'en' && t.respond_to?(:tag_en) && t.tag_en && !t.tag_en.empty?
            t.tag_en
          elsif t.respond_to?(:tag)
            t.tag
          else
            t.to_s
          end
        end
      }
      property :status
      property :likes_count
      property :start_time
      property :duration
      property :relate_url
    end
  end
end
