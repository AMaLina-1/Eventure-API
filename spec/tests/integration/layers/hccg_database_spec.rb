# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'Integration Tests of Hccg API and Database' do
  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr_for_hccg
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Retrieve and store activities' do
    before do
      DatabaseHelper.wipe_database
    end

    it 'HAPPY: should be able to save activities from Hccg to database' do
      activity = Eventure::Hccg::ActivityMapper.new(Eventure::Hccg::Api)
                                               .find(TOP)
                                               .map(&:to_entity)

      repo = Eventure::Repository::For.entity(activity.first)

      rebuilt = repo.create(activity)

      idx = rand(activity.length)

      _(rebuilt[idx].serno).must_equal(activity[idx].serno)
      _(rebuilt[idx].name).must_equal(activity[idx].name)
      _(rebuilt[idx].detail).must_equal(activity[idx].detail)
      _(rebuilt[idx].start_time.to_time).must_equal(activity[idx].start_time.to_time)
      _(rebuilt[idx].end_time.to_time).must_equal(activity[idx].end_time.to_time)
      _(rebuilt[idx].location).must_equal(activity[idx].location)
      _(rebuilt[idx].voice).must_equal(activity[idx].voice)
      _(rebuilt[idx].organizer).must_equal(activity[idx].organizer)
      # _(rebuilt[idx].tag_id).must_equal(activity[idx].tag_id)
      _(rebuilt[idx].tag).must_equal(activity[idx].tag)
      _(rebuilt[idx].relate_url).must_equal(activity[idx].relate_url)
      _(rebuilt[idx].relate_title).must_equal(activity[idx].relate_title)
    end
  end
end
