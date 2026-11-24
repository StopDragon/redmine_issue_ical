# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class UserPreferencePatchTest < ActiveSupport::TestCase
  test 'defaults to keeping closed issues with a mark' do
    pref = UserPreference.new
    assert_equal 'mark', pref.issue_ical_closed
    assert_not pref.issue_ical_hide_closed?
  end

  test 'accepts every option and falls back to mark for unknown values' do
    pref = UserPreference.new
    %w[mark ox status plain hide].each do |option|
      pref.issue_ical_closed = option
      assert_equal option, pref.issue_ical_closed
    end
    assert pref.issue_ical_hide_closed?
    pref.issue_ical_closed = 'bogus'
    assert_equal 'mark', pref.issue_ical_closed
  end

  test 'watched issues are off by default and can be turned on' do
    pref = UserPreference.new
    assert_not pref.issue_ical_watched
    pref.issue_ical_watched = '1'
    assert pref.issue_ical_watched
    pref.issue_ical_watched = '0'
    assert_not pref.issue_ical_watched
  end

  test 'are safe attributes' do
    names = UserPreference.new.safe_attribute_names(User.new)
    assert_includes names, 'issue_ical_closed'
    assert_includes names, 'issue_ical_watched'
  end
end
