# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class CalendarBuilderTest < ActiveSupport::TestCase
  Builder = RedmineIssueIcal::CalendarBuilder

  def event(**attrs)
    Builder::Event.new(uid: 'redmine-issue-1@example.org', summary: 'Task',
                       start_date: Date.new(2026, 12, 1), due_date: Date.new(2026, 12, 3), **attrs)
  end

  def build(*events)
    Builder.new(name: 'Test', now: Time.utc(2026, 11, 25, 9, 0, 0)).build(events)
  end

  test 'date range uses an exclusive end date' do
    assert_equal [Date.new(2026, 12, 1), Date.new(2026, 12, 4)],
                 Builder.date_range(Date.new(2026, 12, 1), Date.new(2026, 12, 3))
  end

  test 'date range falls back to the other date when one is missing' do
    assert_equal [Date.new(2026, 12, 3), Date.new(2026, 12, 4)], Builder.date_range(nil, Date.new(2026, 12, 3))
    assert_equal [Date.new(2026, 12, 1), Date.new(2026, 12, 2)], Builder.date_range(Date.new(2026, 12, 1), nil)
    assert_nil Builder.date_range(nil, nil)
  end

  test 'date range never ends before it starts' do
    assert_equal [Date.new(2026, 12, 5), Date.new(2026, 12, 6)],
                 Builder.date_range(Date.new(2026, 12, 5), Date.new(2026, 12, 3))
  end

  test 'builds an all-day event with CRLF line endings' do
    ics = build(event)
    assert ics.start_with?("BEGIN:VCALENDAR\r\n")
    assert ics.end_with?("END:VCALENDAR\r\n")
    assert_not ics.gsub("\r\n", '').include?("\n")
    assert_includes ics, "DTSTART;VALUE=DATE:20261201\r\n"
    assert_includes ics, "DTEND;VALUE=DATE:20261204\r\n"
    assert_includes ics, "DTSTAMP:20261125T090000Z\r\n"
    assert_includes ics, "UID:redmine-issue-1@example.org\r\n"
  end

  test 'builds a timed event in UTC' do
    ics = build(event(start_at: Time.new(2026, 12, 1, 9, 30, 0, '+09:00'),
                      end_at: Time.new(2026, 12, 3, 18, 0, 0, '+09:00')))
    assert_includes ics, "DTSTART:20261201T003000Z\r\n"
    assert_includes ics, "DTEND:20261203T090000Z\r\n"
    assert_not_includes ics, 'VALUE=DATE'
  end

  test 'events are free unless busy' do
    assert_includes build(event), "TRANSP:TRANSPARENT\r\n"
    assert_includes build(event(busy: true)), "TRANSP:OPAQUE\r\n"
  end

  test 'adds an escaped location when there is one' do
    assert_includes build(event(location: 'Room 3, Seoul')), "LOCATION:Room 3\\, Seoul\r\n"
    assert_not_includes build(event(location: '  ')), 'LOCATION'
    assert_not_includes build(event), 'LOCATION'
  end

  test 'skips events without any date' do
    ics = build(event(start_date: nil, due_date: nil))
    assert_not_includes ics, 'BEGIN:VEVENT'
  end

  test 'escapes text values' do
    ics = build(event(summary: 'a,b;c\\d', description: "line1\nline2"))
    assert_includes ics, 'SUMMARY:a\\,b\\;c\\\\d'
    assert_includes ics, 'DESCRIPTION:line1\\nline2'
  end

  test 'folds long lines at 75 octets without splitting characters' do
    ics = build(event(summary: '한글 제목 ' * 20))
    lines = ics.split("\r\n")
    assert lines.all? { |line| line.bytesize <= 75 }
    assert lines.all?(&:valid_encoding?)
    summary = lines.drop_while { |l| !l.start_with?('SUMMARY:') }
                   .take_while { |l| l.start_with?('SUMMARY:', ' ') }
    assert_equal "SUMMARY:#{'한글 제목 ' * 20}", summary.map { |l| l.delete_prefix(' ') }.join
  end
end
