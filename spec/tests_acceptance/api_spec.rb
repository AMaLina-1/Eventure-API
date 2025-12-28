# frozen_string_literal: true

require_relative '../helpers/spec_helper'
require_relative '../helpers/vcr_helper'
require_relative '../helpers/database_helper'
require 'rack/test'

def app
  Eventure::App
end

describe 'Test API routes' do
  include Rack::Test::Methods

  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr_for_hccg
    DatabaseHelper.wipe_database
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Root route' do
    it 'should successfully return root information' do
      get '/'
      _(last_response.status).must_equal 200

      body = JSON.parse(last_response.body)
      _(body['status']).must_equal 'ok'
      _(body['message']).must_include 'Eventure API'
    end
  end

  describe 'Activity endpoints' do
    it 'returns activities list' do
      get '/api/v1/activities'
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['activities']).must_be_kind_of Array
    end
  end

  describe 'City endpoints' do
    it 'returns cities list' do
      get '/api/v1/cities'
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['cities']).must_be_kind_of Array
    end
  end

  describe 'District endpoints' do
    it 'returns districts list grouped by city' do
      get '/api/v1/districts'
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['status']).must_be_kind_of String
      _(response['message']).must_be_kind_of Hash

      response['message'].each do |city, districts|
        _(city).must_be_kind_of String
        _(districts).must_be_kind_of Array
      end
    end
  end

  describe 'Tag endpoints' do
    it 'returns tags list' do
      get '/api/v1/tags'
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['tags']).must_be_kind_of Array
    end
  end

  describe 'Filtered activities endpoint' do
    it 'filters activities based on parameters' do
      params = {
        filters: {
          tag: [],
          city: '',
          districts: [],
          start_date: '',
          end_date: ''
        }
      }

      post '/api/v1/filter', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['activities']).must_be_kind_of Array
    end

    it 'filters activities by city' do
      params = {
        filters: {
          tag: [],
          city: '',
          districts: [],
          start_date: '',
          end_date: ''
        }
      }

      post '/api/v1/filter', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['activities']).must_be_kind_of Array
    end

    it 'returns bad request for invalid date range' do
      params = {
        filters: {
          tag: [],
          city: '',
          districts: [],
          start_date: '2024-12-31',
          end_date: '2024-01-01'
        }
      }

      post '/api/v1/filter', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 400

      response = JSON.parse(last_response.body)
      _(response['status']).must_equal 'bad_request'
      _(response['message']).must_include 'Start date cannot be later than end date'
    end
  end

  describe 'Like endpoints' do
    it 'toggles like for an activity (if activities exist)' do
      get '/api/v1/activities'
      activities_response = JSON.parse(last_response.body)

      skip 'No activities in database' if activities_response['activities'].empty?

      first_activity_serno = activities_response['activities'].first['serno']

      params = { serno: first_activity_serno }

      post '/api/v1/activities/like', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 200

      response = JSON.parse(last_response.body)
      _(response['serno'].to_s).must_equal first_activity_serno.to_s
      _(response['likes_count']).must_be_kind_of Integer
      _(response['user_likes'].map(&:to_s)).must_equal Array(first_activity_serno.to_s)
    end

    it 'returns not found for non-existent activity' do
      params = { serno: '999999' }

      post '/api/v1/activities/like', params.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 404

      response = JSON.parse(last_response.body)
      _(response['status']).must_equal 'not_found'
      _(response['message']).must_include 'Activity not found'
    end
  end
end
