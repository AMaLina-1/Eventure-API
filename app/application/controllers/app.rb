# frozen_string_literal: true

require 'roda'
require_relative '../services/api_activities'

module Eventure
  class App < Roda
    plugin :flash
    plugin :halt
    plugin :all_verbs # allows DELETE and other HTTP verbs beyond GET/POST

    route do |routing|
      response['Content-Type'] = 'application/json'
      # ================== Write Database ==================
      # The app previously saved activities on every request which causes
      # frequent writes and locks (SQLite busy). Commented out so we don't
      # sync on each HTTP request. If you want periodic sync, run a rake
      # task or background job at startup/cron instead.
      # routing.post '/' do
      puts "fetch_api_activities called"
      result = Service::ApiActivities.new.call(total: 100)
      if result.failure?
        print('Failed to fetch api activities')
          # failed = Representer::HttpResponse.new(result.failure)
          # response.status = failed.http_status_code
          # failed.to_json
      else
        puts 'successfully fetched and saved activities'
          # api_result = result.value!

          # http_response = Representer::HttpResponse.new(api_result)
          # response.status = http_response.http_status_code

          # fetch_result_msg = api_result.message[:msg]
          # fetch_result = OpenStruct.new(msg: fetch_result_msg)
          # Representer::FetchApiData.new(fetch_result).to_json
      end

      routing.root do
        message = { status: 'ok', message: 'Eventure API v1' }
        response.status = 200
        message.to_json
      end

      routing.on 'api/v1' do
        lang = routing.params['lang'] || 'zh-TW'
        routing.on 'activities' do
          routing.is do
            routing.get do
              # Always use SearchedActivities; it returns the full list when no keyword
              result = Service::SearchedActivities.new.call(
                keyword: routing.params['keyword'],
                language: lang
              )

              if result.failure?
                failed = Representer::HttpResponse.new(result.failure)
                response.status = failed.http_status_code
                failed.to_json
              else
                api_result = result.value!
                activities_list = api_result.message
                http_response = Representer::HttpResponse.new(api_result)
                response.status = http_response.http_status_code
                # ActivityList expects an object with `activities` collection
                Representer::ActivityList.new(
                  OpenStruct.new(activities: activities_list),
                  language: lang
                ).to_json
              end
            end
          end

          routing.on 'like' do
            routing.post do
              request_data = JSON.parse(routing.body.read)
              serno = request_data['serno'].to_s
              user_likes = Array(request_data['user_likes']).map(&:to_s)
              result = Service::UpdateLikeCounts.new.call(serno: serno, user_likes: user_likes)

              if result.failure?
                failed = Representer::HttpResponse.new(result.failure)
                response.status = failed.http_status_code
                failed.to_json
              else
                api_result = result.value!
                result_data = api_result.message
                like_response = OpenStruct.new(serno: result_data[:serno], likes_count: result_data.like_counts,
                                               user_likes: result_data[:user_likes])

                http_response = Representer::HttpResponse.new(api_result)
                response.status = http_response.http_status_code
                Representer::ActivityLike.new(like_response).to_json
              end
            end
          end
        end

        routing.on 'filter' do
          routing.post do
            request_data = JSON.parse(routing.body.read)
            filters = request_data['filters'] || {}

            clean_filters = {
              tag: Array(filters['tag']).map(&:to_s).reject(&:empty?),
              city: filters['city']&.to_s || '',
              districts: Array(filters['districts']).map(&:to_s).reject(&:empty?),
              start_date: filters['start_date']&.to_s || '',
              end_date: filters['end_date']&.to_s || '',
              language: filters['language']&.to_s || lang
            }
            # puts clean_filters
            result = Service::FilteredActivities.new.call(filters: clean_filters)
            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!

              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code

              result_activities = api_result.message[:activities]
              activities_list = OpenStruct.new(activities: result_activities)
              actual_language = clean_filters[:language]
              Representer::ActivityList.new(activities_list, language: actual_language).to_json
            end
          end
        end

        routing.on 'cities' do
          routing.get do
            result = Service::ListCity.new.call(language: lang)

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              cities_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              Representer::CityList.new(cities_list, language: lang).to_json
            end
          end
        end

        routing.on 'districts' do
          routing.get do
            result = Service::ListDistrict.new.call(language: lang)

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              districts_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              { status: api_result.status, message: districts_list.districts }.to_json
            end
          end
        end

        routing.on 'tags' do
          routing.get do
            result = Service::ListTag.new.call(language: lang)

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              tags_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              Representer::TagList.new(tags_list, language: lang).to_json
            end
          end
        end
      end
    end
  end
end
