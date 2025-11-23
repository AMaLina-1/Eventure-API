# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'UpdateLikeCounts Service Integration Test' do
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

  describe 'Do updating like transaction' do
    before do
      DatabaseHelper.wipe_database
      @activities = Eventure::Hccg::ActivityMapper.new(Eventure::Hccg::Api).find(TOP)
      Eventure::Repository::Activities.create(@activities)
      @user_likes = @activities[0..1].map(&:serno)
    end

    it 'HAPPY: should fetch activity with certain serno' do
      target_serno = @activities[0].serno
      result = Eventure::Service::UpdateLikeCounts.new.call(serno: target_serno, user_likes: @user_likes)
      _(result.success?).must_equal true
    end

    it 'HAPPY: should properly "like" an activity' do
      target_serno = @activities[5].serno
      original_like_counts = @activities[5].likes_count
      result = Eventure::Service::UpdateLikeCounts.new.call(serno: target_serno, user_likes: @user_likes)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt.user_likes).must_include target_serno
      _(rebuilt.like_counts).must_equal original_like_counts + 1
      _(rebuilt.like_counts).must_equal Eventure::Repository::Activities.find_serno(target_serno).likes_count
    end

    it 'HAPPY: should properly "dislike" an activity' do
      target_serno = @activities[0].serno
      original_like_counts = @activities[0].likes_count
      result = Eventure::Service::UpdateLikeCounts.new.call(serno: target_serno, user_likes: @user_likes)
      _(result.success?).must_equal true
      api_result = result.value!
      rebuilt = api_result.message

      _(rebuilt.user_likes).wont_include target_serno
      _(rebuilt.like_counts).must_equal(original_like_counts > 0 ? original_like_counts - 1 : 0)
      _(rebuilt.like_counts).must_equal Eventure::Repository::Activities.find_serno(target_serno).likes_count
    end

    it 'BAD: should gracefully fail for invalid serno' do
      result = Eventure::Service::UpdateLikeCounts.new.call(serno: 123, user_likes: @user_likes)
      _(result.success?).must_equal false
      _(result.failure.message).must_equal 'Activity not found'
    end
  end
end
