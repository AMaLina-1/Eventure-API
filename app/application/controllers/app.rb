# frozen_string_literal: true

require 'roda'

module Eventure
  class App < Roda
    plugin :flash
    plugin :halt
    plugin :all_verbs # allows DELETE and other HTTP verbs beyond GET/POST

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        message = { status: 'ok', message: 'Eventure API v1' }
        response.status = 200
        message.to_json
      end

      routing.on 'api/v1' do
        routing.on 'activities' do
          routing.is do
            routing.get do
              result = Service::ListActivity.new.call({})

              if result.failure?
                failed = Representer::HttpResponse.new(result.failure)
                response.status = failed.http_status_code
                failed.to_json
              else
                api_result = result.value!
                activities_list = api_result.message
                http_response = Representer::HttpResponse.new(api_result)
                response.status = http_response.http_status_code
                Representer::ActivityList.new(activities_list).to_json
              end
            end
          end

          routing.on 'like' do
            routing.post do
              request_data = JSON.parse(routing.body.read)
              serno = request_data['serno']
              session[:user_likes] ||= []

              result = Service::UpdateLikeCounts.new.call(serno: serno.to_i, user_likes: session[:user_likes])

              if result.failure?
                failed = Representer::HttpResponse.new(result.failure)
                response.status = failed.http_status_code
                failed.to_json
              else
                api_result = result.value!
                result_data = api_result.message
                session[:user_likes] = result_data.user_likes

                like_response = OpenStruct.new(serno: serno.to_i, likes_count: result_data.like_counts, liked: session[:user_likes].include?(serno.to_i))

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
              end_date: filters['end_date']&.to_s || ''
            }

            result = Service::FilteredActivities.new.call(filters: clean_filters)

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              activities_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              Representer::ActivityList.new(activities_list).to_json
            end
          end
        end

        routing.on 'cities' do
          routing.get do
            result = Service::ListCity.new.call({})

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              cities_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              Representer::CityList.new(cities_list).to_json
            end
          end
        end

        routing.on 'districts' do
          routing.get do
            result = Service::ListDistrict.new.call({})

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
            result = Service::ListTag.new.call({})

            if result.failure?
              failed = Representer::HttpResponse.new(result.failure)
              response.status = failed.http_status_code
              failed.to_json
            else
              api_result = result.value!
              tags_list = api_result.message
              http_response = Representer::HttpResponse.new(api_result)
              response.status = http_response.http_status_code
              Representer::TagList.new(tags_list).to_json
            end
          end
        end
      end
    end
  end
end
