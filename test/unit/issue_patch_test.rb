# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class IssuePatchTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :projects_trackers, :enabled_modules,
           :enumerations, :issue_categories, :versions

  def setup
    User.current = User.find(2) # jsmith, member of project 2 (issue 4)
    Setting.default_language = 'en'
    @start_field = time_field('Start time')
    @end_field = time_field('End time')
  end

  def teardown
    User.current = nil
  end

  def time_field(name, tracker_ids: Tracker.pluck(:id))
    IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true, tracker_ids: tracker_ids)
  end

  def with_time_settings(&block)
    settings = { 'start_time_field_id' => @start_field.id.to_s, 'end_time_field_id' => @end_field.id.to_s }
    with_settings(plugin_redmine_issue_ical: settings, &block)
  end

  def issue_with(start_time, end_time)
    issue = Issue.find(4)
    issue.custom_field_values = { @start_field.id.to_s => start_time, @end_field.id.to_s => end_time }
    issue
  end

  test 'a start time without an end time is rejected' do
    with_time_settings do
      issue = issue_with('09:00', '')
      assert_not issue.valid?
      assert_includes issue.errors.full_messages.join, 'End time is required when Start time is filled in'
    end
  end

  test 'an end time without a start time is rejected' do
    with_time_settings do
      issue = issue_with('', '23:30')
      assert_not issue.valid?
      assert_includes issue.errors.full_messages.join, 'Start time is required when End time is filled in'
    end
  end

  test 'both times or none are fine' do
    with_time_settings do
      assert issue_with('09:00', '18:00').valid?
      assert issue_with('', '').valid?
    end
  end

  test 'an older issue with a single time can still be edited for other reasons' do
    CustomValue.create!(customized: Issue.find(4), custom_field: @end_field, value: '23:30')
    with_time_settings do
      issue = Issue.find(4)
      issue.subject = 'Renamed'
      assert issue.valid?, issue.errors.full_messages.join
    end
  end

  test 'no check without the plugin settings' do
    assert issue_with('09:00', '').valid?
  end

  test 'no check when a time field is not enabled for the tracker' do
    @end_field.update!(tracker_ids: Tracker.where.not(id: Issue.find(4).tracker_id).pluck(:id))
    with_time_settings do
      assert issue_with('09:00', '').valid?
    end
  end
end
