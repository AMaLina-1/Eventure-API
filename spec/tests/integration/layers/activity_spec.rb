# frozen_string_literal: true

require_relative '../../../helpers/spec_helper'
require_relative '../../../helpers/vcr_helper'
require_relative '../../../helpers/database_helper'

describe 'Activity entity domain logic tests' do
  VcrHelper.setup_vcr

  before do
    VcrHelper.configure_vcr_for_hccg
    @activities = Eventure::Hccg::ActivityMapper.new(Eventure::Hccg::Api)
                                                .find(TOP)
                                                .map(&:to_entity)
  end

  after do
    VcrHelper.eject_vcr
  end

  describe 'Activity entity structure from API data' do
    it 'HAPPY: should load activities from API with correct datatypes' do
      _(@activities.length).must_be :>, 0
      _(@activities.length).must_be :<=, TOP

      @activities.each do |activity|
        _(activity).must_be_kind_of Eventure::Entity::Activity
        _(activity.serno).must_be_kind_of String
        _(activity.name).must_be_kind_of String
        _(activity.detail).must_be_kind_of String
        _(activity.voice).must_be_kind_of String
        _(activity.organizer).must_be_kind_of String
      end
    end

    it 'HAPPY: should have location value object for all activities' do
      @activities.each do |activity|
        _(activity.location).must_be_kind_of Eventure::Value::Location
        _(activity.building).wont_be_nil
      end
    end

    it 'HAPPY: should have activity_date value object for all activities' do
      @activities.each do |activity|
        _(activity.activity_date).must_be_kind_of Eventure::Value::ActivityDate
        _(activity.start_time).must_be_kind_of DateTime
        _(activity.end_time).must_be_kind_of DateTime
      end
    end

    it 'HAPPY: should have tags array (may be empty)' do
      @activities.each do |activity|
        _(activity.tags).must_be_kind_of Array
      end

      activities_with_tags = @activities.select { |a| a.tags.any? }
      _(activities_with_tags.length).must_be :>, 0
    end

    it 'HAPPY: should have all tag entities with correct type' do
      @activities.each do |activity|
        activity.tags.each do |tag|
          _(tag).must_be_kind_of Eventure::Entity::Tag
          _(tag.tag).must_be_kind_of String
          _(tag.tag).wont_be_empty
        end
      end
    end

    it 'HAPPY: should have relate_data array (may be empty)' do
      @activities.each do |activity|
        _(activity.relate_data).must_be_kind_of Array
      end
    end

    it 'HAPPY: should have correct relate_data entities when present' do
      @activities.each do |activity|
        activity.relate_data.each do |relate|
          _(relate).must_be_kind_of Eventure::Entity::RelateData
          _(relate.relate_title).must_be_kind_of String
          _(relate.relate_url).must_be_kind_of String
        end
      end
    end
  end

  describe 'Activity date delegation with API data' do
    it 'HAPPY: should delegate start_time correctly for all activities' do
      @activities.each do |activity|
        _(activity.start_time).must_equal activity.activity_date.start_time
      end
    end

    it 'HAPPY: should delegate end_time correctly for all activities' do
      @activities.each do |activity|
        _(activity.end_time).must_equal activity.activity_date.end_time
      end
    end

    it 'HAPPY: should have end_time after or equal to start_time' do
      @activities.each do |activity|
        _(activity.end_time).must_be :>=, activity.start_time
      end
    end

    it 'HAPPY: should provide valid status from activity_date' do
      valid_statuses = %w[Archived Expired Ongoing Upcoming Scheduled]

      @activities.each do |activity|
        status = activity.status
        _(status).must_be_kind_of String
        _(valid_statuses).must_include status
      end
    end

    it 'HAPPY: should calculate duration string for all activities' do
      @activities.each do |activity|
        duration = activity.duration
        _(duration).must_be_kind_of String
        _(duration).must_match(/\d+ days \d+ hours \d+ minutes/)
      end
    end

    it 'HAPPY: should have variety in activity statuses' do
      statuses = @activities.map(&:status).uniq
      _(statuses.length).must_be :>, 0
      puts "      Found statuses: #{statuses.join(', ')}"
    end
  end

  describe 'Activity location delegation with API data' do
    it 'HAPPY: should delegate city from location for all activities' do
      @activities.each do |activity|
        _(activity.city).must_be_kind_of String
        _(activity.city).wont_be_empty
        _(activity.city).must_equal activity.location.city
      end
    end

    it 'HAPPY: should delegate district from location for all activities' do
      @activities.each do |activity|
        _(activity.district).must_be_kind_of String
        _(activity.district).must_equal activity.location.district
      end
    end

    it 'HAPPY: should provide building as location string' do
      @activities.each do |activity|
        building = activity.building
        _(building).must_be_kind_of String
        _(building).must_equal activity.location.to_s
      end
    end

    it 'HAPPY: should provide region equal to city' do
      @activities.each do |activity|
        _(activity.region).must_equal activity.city
      end
    end
  end

  describe 'Activity tags extraction with API data' do
    it 'HAPPY: should extract tag strings matching tag entities' do
      @activities.each do |activity|
        tag_strings = activity.tag
        _(tag_strings).must_be_kind_of Array
        _(tag_strings.length).must_equal activity.tags.length

        if activity.tags.any?
          _(tag_strings.all? { |t| t.is_a?(String) }).must_equal true
          _(tag_strings.all? { |t| !t.empty? }).must_equal true
        end
      end
    end

    it 'HAPPY: should have tag method match tags.map(&:tag)' do
      @activities.each do |activity|
        extracted_tags = activity.tag
        entity_tags = activity.tags.map(&:tag)
        _(extracted_tags).must_equal entity_tags
      end
    end

    it 'HAPPY: should parse tag strings correctly from subjectclass' do
      activities_with_tags = @activities.select { |a| a.tags.any? }
      _(activities_with_tags.length).must_be :>, 0

      activities_with_tags.each do |activity|
        activity.tag.each do |tag_string|
          # Tags from API are like "[100]內政及國土", mapper extracts "內政及國土"
          _(tag_string).wont_match(/^\[/)
          _(tag_string).wont_be_empty
        end
      end
    end
  end

  describe 'Activity relate_data extraction with API data' do
    it 'HAPPY: should extract relate URLs correctly when present' do
      @activities.each do |activity|
        urls = activity.relate_url
        _(urls).must_be_kind_of Array
        _(urls.length).must_equal activity.relate_data.length

        _(urls.all? { |url| url.is_a?(String) }).must_equal true if activity.relate_data.any?
      end
    end

    it 'HAPPY: should extract relate titles correctly when present' do
      @activities.each do |activity|
        titles = activity.relate_title
        _(titles).must_be_kind_of Array
        _(titles.length).must_equal activity.relate_data.length

        _(titles.all? { |title| title.is_a?(String) }).must_equal true if activity.relate_data.any?
      end
    end

    it 'HAPPY: should match extracted data with relate_data entities' do
      @activities.each do |activity|
        extracted_urls = activity.relate_url
        entity_urls = activity.relate_data.map(&:relate_url)
        _(extracted_urls).must_equal entity_urls

        extracted_titles = activity.relate_title
        entity_titles = activity.relate_data.map(&:relate_title)
        _(extracted_titles).must_equal entity_titles
      end
    end

    it 'HAPPY: should return empty arrays for activities without relate_data' do
      activities_without_relate = @activities.select { |a| a.relate_data.empty? }

      activities_without_relate.each do |activity|
        _(activity.relate_url).must_be_empty
        _(activity.relate_title).must_be_empty
      end
    end
  end

  describe 'Activity likes functionality' do
    before do
      @test_activity = @activities.first
    end

    it 'HAPPY: should initialize with zero likes for all activities' do
      @activities.each do |activity|
        _(activity.likes_count).must_equal 0
      end
    end

    it 'HAPPY: should increment likes count' do
      initial_count = @test_activity.likes_count
      @test_activity.add_likes

      _(@test_activity.likes_count).must_equal initial_count + 1
    end

    it 'HAPPY: should increment likes multiple times' do
      3.times { @test_activity.add_likes }
      _(@test_activity.likes_count).must_equal 3
    end

    it 'HAPPY: should decrement likes count' do
      2.times { @test_activity.add_likes }
      @test_activity.remove_likes

      _(@test_activity.likes_count).must_equal 1
    end

    it 'HAPPY: should not allow negative likes count' do
      5.times { @test_activity.remove_likes }

      _(@test_activity.likes_count).must_equal 0
      _(@test_activity.likes_count).must_be :>=, 0
    end

    it 'HAPPY: should handle mixed add and remove operations' do
      @test_activity.add_likes
      @test_activity.add_likes
      @test_activity.add_likes
      @test_activity.remove_likes
      @test_activity.add_likes

      _(@test_activity.likes_count).must_equal 3
    end

    it 'HAPPY: should maintain independent like counts per activity' do
      activity1 = @activities[0]
      activity2 = @activities[1]

      2.times { activity1.add_likes }
      1.times { activity2.add_likes }

      _(activity1.likes_count).must_equal 2
      _(activity2.likes_count).must_equal 1
    end
  end

  describe 'Activity to_entity method' do
    it 'HAPPY: should return itself maintaining object identity' do
      @activities.each do |activity|
        entity = activity.to_entity
        _(entity).must_equal activity
        _(entity.object_id).must_equal activity.object_id
      end
    end
  end

  describe 'Activity data consistency validation' do
    it 'HAPPY: should have unique serial numbers across all activities' do
      sernos = @activities.map(&:serno)
      unique_sernos = sernos.uniq

      _(unique_sernos.length).must_equal sernos.length
    end

    it 'HAPPY: should have non-empty required string fields' do
      @activities.each do |activity|
        _(activity.serno).wont_be_empty
        _(activity.name).wont_be_empty
        _(activity.organizer).must_be_kind_of String
      end
    end

    it 'HAPPY: should have valid date ranges with positive duration' do
      @activities.each do |activity|
        duration_in_seconds = (activity.end_time - activity.start_time) * 24 * 60 * 60
        _(duration_in_seconds).must_be :>=, 0
      end
    end

    it 'HAPPY: should have sernos matching expected format' do
      @activities.each do |activity|
        _(activity.serno).must_match(/^\d+$/)
        _(activity.serno.length).must_be :>, 0
      end
    end
  end

  describe 'Activity entity immutability' do
    it 'HAPPY: should not modify original activity when accessing attributes' do
      original_activity = @activities.first
      original_name = original_activity.name
      original_tags_count = original_activity.tags.length

      # Access various attributes
      _name = original_activity.name
      _tags = original_activity.tag
      _city = original_activity.city
      _status = original_activity.status

      # Original should remain unchanged
      _(original_activity.name).must_equal original_name
      _(original_activity.tags.length).must_equal original_tags_count
    end
  end
end
