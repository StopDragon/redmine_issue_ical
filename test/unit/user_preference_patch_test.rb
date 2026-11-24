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

  test 'is a safe attribute' do
    assert_includes UserPreference.new.safe_attribute_names(User.new), 'issue_ical_closed'
  end
end
