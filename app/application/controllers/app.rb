# frozen_string_literal: true

require 'roda'
require 'slim'
require 'slim/include'
require_relative '../../presentation/view_objects/activity_list'
require_relative '../../presentation/view_objects/filter'
require_relative '../../presentation/view_objects/filter_option'
require_relative '../services/filtered_activities'
require_relative '../services/update_like_counts'

module Eventure
  class App < Roda
    plugin :flash
    plugin :render, engine: 'slim', views: 'app/presentation/views_html'
    plugin :static, ['/assets'], root: 'app/presentation'
    plugin :common_logger, $stdout
    plugin :halt
    plugin :all_verbs # allows DELETE and other HTTP verbs beyond GET/POST

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'

      routing.root do
        if session[:seen_intro_where]
          routing.redirect '/activities'
        else
          session[:seen_intro_where] = true
          view 'intro_where'
        end
      end

      routing.get 'intro_where' do
        view 'intro_where'
      end

      routing.get 'intro_tag' do
        # 先把這次帶進來的條件轉成乾淨 hash（包含 filter_city）
        filters = extract_filters(routing) # => { tag: [...], city: '新竹市', ... }

        # 目前只需要這次送來的條件就好
        session[:filters] = filters

        all_activities = Eventure::Repository::Activities.all

        # 若有指定 city，只拿該 city 的活動來產生 tag 選單
        activities_for_options =
          if filters[:city] && !filters[:city].empty?
            all_activities.select { |a| a.city.to_s == filters[:city].to_s }
          else
            all_activities
          end

        @current_filters = Views::Filter.new(filters || {})
        @filter_options  = Views::FilterOption.new(activities_for_options)

        view 'intro_tag',
             locals: view_locals.merge(
               liked_sernos: Array(session[:user_likes]).map(&:to_i)
             )
      end

      # ================== Likes page ==================
      routing.get 'like' do
        liked_sernos = Array(session[:user_likes]).map(&:to_i)
        liked_activities = liked_sernos.map { |serno| Eventure::Repository::Activities.find_serno(serno) }.compact

        view 'like',
             locals: view_locals.merge(
               cards: Views::ActivityList.new(liked_activities),
               liked_sernos: liked_sernos
             )
      end

      # ================== Activities ==================
      routing.on 'activities' do
        routing.is do
          session[:filters] = extract_filters(routing)
          result = Eventure::Service::FilteredActivities.new.call(filters: session[:filters])

          if result.failure?
            flash[:error] = result.failure
            routing.redirect '/activities'
          else
            result = result.value!
            @filtered_activities = result[:filtered_activities]
            show_activities(result[:all_activities])
          end
        end

        routing.post 'like' do
          response['Content-Type'] = 'application/json'
          serno = routing.params['serno'] || routing.params['serno[]']
          session[:user_likes] ||= []

          result = Service::UpdateLikeCounts.new.call(serno: serno.to_i, user_likes: session[:user_likes])

          if result.failure?
            flash[:error] = result.failure
          else
            result = result.value!
            session[:user_likes] = result[:user_likes]
            { serno: serno.to_i, likes_count: result[:like_counts] }.to_json
          end
        end
      end
    end

    # ================== Show Activities ==================
    def show_activities(all)
      @current_filters = Views::Filter.new(session[:filters])
      @filter_options = Views::FilterOption.new(all)
      view 'home',
           locals: view_locals.merge(
             liked_sernos: Array(session[:user_likes]).map(&:to_i)
           )
    end

    # 把 params 換成乾淨 hash
    def extract_filters(routing)
      {
        tag: Array(routing.params['filter_tag'] || routing.params['filter_tag[]']).map(&:to_s).reject(&:empty?),
        city: routing.params['filter_city']&.to_s,
        districts: Array(routing.params['filter_district'] || routing.params['filter_district[]'])
          .map(&:to_s).reject(&:empty?),
        start_date: routing.params['filter_start_date']&.to_s,
        end_date: routing.params['filter_end_date']&.to_s
      }
    end

    def view_locals
      {
        cards: Views::ActivityList.new(@filtered_activities || activities),
        total_pages: 1,
        current_page: 1
      }
    end

    def activities
      @activities ||= Eventure::Repository::Activities.all
    end

    def service
      @service ||= Eventure::Services::ActivityService.new
    end
  end
end
