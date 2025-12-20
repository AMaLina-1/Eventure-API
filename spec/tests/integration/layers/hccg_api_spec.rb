# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../../app/infrastructure/hccg/gateways/hccg_api'

describe 'Tests hccg activity API library' do
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

  describe 'Error raising' do
    it 'SAD: should raise exception on invalid top argument' do
      error = _(
        proc {
          @data = Eventure::Hccg::ActivityMapper
                 .new(Eventure::Hccg::Api)
                 .find(101)
        }
      ).must_raise RuntimeError
      _(error.message).must_equal 'Request Failed'
    end
  end

  describe 'Data content and structure' do
    before do
      @data = Eventure::Hccg::ActivityMapper.new(Eventure::Hccg::Api).find(TOP)
    end

    it 'HAPPY: should provide correct information' do
      idx = rand(@data.length)
      _(@data[idx].serno).must_be_kind_of String
      _(@data[idx].serno).must_equal CORRECT[idx]['serno'].to_s
      _(@data[idx].name).wont_be_nil
      _(@data[idx].name).must_equal CORRECT[idx]['subject']
      _(@data[idx].detail).must_equal CORRECT[idx]['detailcontent']
      _(@data[idx].location.to_s).must_equal "新竹市#{CORRECT[idx]['activityplace']}"
      _(@data[idx].voice).must_equal CORRECT[idx]['voice']
      _(@data[idx].organizer).wont_be_nil
      _(@data[idx].organizer).must_equal CORRECT[idx]['hostunit']
    end

    it 'HAPPY: should provide correct time' do
      idx = rand(@data.length)
      _(@data[idx].start_time).must_be_kind_of DateTime
      _(@data[idx].end_time).must_be :>=, @data[idx].start_time
    end

    it 'HAPPY: should provide correct tags' do
      idx = rand(@data.length)
      _(@data[idx].tag).must_be_kind_of Array
      _(@data[idx].tags).must_be_kind_of Array
      _(@data[idx].tags[0]).must_be_kind_of Eventure::Entity::Tag if @data[idx].tags.any?
      _(@data[idx].tag).must_equal(CORRECT[idx]['subjectclass'].split(',').map { |item| item.split(']')[1] })
    end

    it 'HAPPY: should provide correct relatedata' do
      idx = rand(@data.length)
      _(@data[idx].relate_url).must_be_kind_of Array
      _(@data[idx].relate_title.length).must_equal CORRECT[idx]['resourcedatalist'].length
    end

    it 'HAPPY: should provide correct datatype and length' do
      _(@data[0].to_entity).must_be_kind_of Eventure::Entity::Activity
      _(@data.length).must_equal TOP
    end
  end
end
