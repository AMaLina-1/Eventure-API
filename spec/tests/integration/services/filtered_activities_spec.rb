# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'FilteredActivities Service Integration Test' do
  VCR.configure do |c|
    c.cassette_library_dir = CASSETTES_FOLDER
    c.hook_into :webmock
  end

  before do
    VCR.insert_cassette CASSETTE_FILE,
                        record: :new_episodes,
                        match_requests_on: %i[method uri headers]
  end

  after do
    VCR.eject_cassette
  end

  describe 'Do filter transaction' do
    before do
      DatabaseHelper.wipe_database
      activities = Eventure::Hccg::ActivityMapper.new(Eventure::Hccg::Api).find(TOP)
      Eventure::Repository::Activities.create(activities)
    end

    it 'HAPPY: should return all activities' do
      filters = { tag: [], city: nil, districts: [], start_date: nil, end_date: nil }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt[:all_activities]).must_equal Eventure::Repository::Activities.all
      _(rebuilt[:filtered_activities]).must_equal Eventure::Repository::Activities.all
    end

    it 'HAPPY: should be filtered by tags' do
      args = '教育文化'
      filters = { tag: [args], city: nil, districts: [], start_date: nil, end_date: nil }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt[:filtered_activities].all? { |activity| activity.tag.include?(args) }).must_equal true
    end

    it 'HAPPY: should be filtered by city' do
      args = '新竹'
      filters = { tag: [], city: args, districts: [], start_date: nil, end_date: nil }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt[:filtered_activities].all? { |activity| activity.city == args }).must_equal true
    end

    it 'HAPPY: should be filtered by districts (specific)' do
      args = %w[新竹 東區]
      filters = { tag: [], city: args[0], districts: [args[1]], start_date: nil, end_date: nil }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt[:filtered_activities].all? do |activity|
        activity.city == args[0] && [args[1]].include?(activity.district)
      end).must_equal true
    end

    it 'HAPPY: should be filtered by districts (all)' do
      args = %w[新竹 全區]
      filters1 = { tag: [], city: args[0], districts: [args[1]], start_date: nil, end_date: nil }
      result1 = Eventure::Service::FilteredActivities.new.call(filters: filters1)
      _(result1.success?).must_equal true
      api_result1 = result1.value!
      rebuilt1 = api_result1.message

      filters2 = { tag: [], city: args[0], districts: [], start_date: nil, end_date: nil }
      result2 = Eventure::Service::FilteredActivities.new.call(filters: filters2)
      _(result2.success?).must_equal true
      api_result2 = result2.value!
      rebuilt2 = api_result2.message

      _(rebuilt1[:filtered_activities].all? { |activity| activity.city == args[0] }).must_equal true
      _(rebuilt1[:filtered_activities].length).must_equal rebuilt2[:filtered_activities].length
    end

    it 'HAPPY: should be filtered by dates' do
      args = %w[2025-11-01 2025-12-31]
      filters = { tag: [], city: nil, districts: [], start_date: args[0], end_date: args[1] }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt[:filtered_activities].all? do |activity|
        activity.start_time.between?(DateTime.parse(args[0]), DateTime.parse(args[1]))
      end).must_equal true
    end

    it 'BAD: should gracefully fail for invalid dates' do
      args = %w[2025-12-31 2025-11-01]
      filters = { tag: [], city: nil, districts: [], start_date: args[0], end_date: args[1] }
      result = Eventure::Service::FilteredActivities.new.call(filters: filters)
      _(result.success?).must_equal false
      _(result.failure.message).must_equal 'Start date cannot be later than end date'
    end
  end
end
