# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class EventTimeTest < ActiveSupport::TestCase
  EventTime = RedmineIssueIcal::EventTime

  def span(first, last, start_value, end_value)
    EventTime.span(first, last, start_value, end_value) do |date, hour, minute|
      Time.utc(date.year, date.month, date.day, hour, minute)
    end
  end

  test 'parses times with or without a colon' do
    assert_equal [9, 30], EventTime.parse('09:30')
    assert_equal [9, 30], EventTime.parse('9:30')
    assert_equal [9, 30], EventTime.parse('0930')
    assert_equal [9, 30], EventTime.parse('930')
    assert_equal [9, 0], EventTime.parse('9')
    assert_equal [23, 59], EventTime.parse(' 23:59 ')
    assert_equal [9, 30], EventTime.parse('09:30:00')
    assert_equal [9, 30], EventTime.parse("09\uFF1A30")
  end

  test 'rejects blank and invalid times' do
    [nil, '', '24:00', '12:60', 'abc', '9:3', '12345', '9.30', '09:30:60', '9:30:'].each do |value|
      assert_nil EventTime.parse(value), value.inspect
    end
  end

  test 'start and end time span from the first to the last day' do
    assert_equal [Time.utc(2026, 11, 17, 9, 30), Time.utc(2026, 11, 27, 18, 0)],
                 span(Date.new(2026, 11, 17), Date.new(2026, 11, 27), '09:30', '18:00')
  end

  test 'without an end time the event lasts one hour on the last day' do
    assert_equal [Time.utc(2026, 11, 17, 9, 30), Time.utc(2026, 11, 17, 10, 30)],
                 span(Date.new(2026, 11, 17), Date.new(2026, 11, 17), '09:30', nil)
    assert_equal [Time.utc(2026, 11, 17, 9, 30), Time.utc(2026, 11, 19, 10, 30)],
                 span(Date.new(2026, 11, 17), Date.new(2026, 11, 19), '09:30', '')
  end

  test 'an end before the start becomes one hour from the start' do
    assert_equal [Time.utc(2026, 11, 17, 14, 0), Time.utc(2026, 11, 17, 15, 0)],
                 span(Date.new(2026, 11, 17), Date.new(2026, 11, 17), '14:00', '09:00')
  end

  test 'stays all-day without a valid start time' do
    assert_nil span(Date.new(2026, 11, 17), Date.new(2026, 11, 17), nil, '18:00')
    assert_nil span(Date.new(2026, 11, 17), Date.new(2026, 11, 17), 'soon', '18:00')
  end
end
