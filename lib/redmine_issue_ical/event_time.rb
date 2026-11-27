# frozen_string_literal: true

require 'date'

module RedmineIssueIcal
  # Start and end times typed into issue custom fields ("09:30", "9:30", "0930").
  # Plain Ruby so it can be tested without a Redmine instance.
  module EventTime
    ONE_HOUR = 3600

    module_function

    # "09:30", "9:30", "0930", "930" and "9" become [9, 30] / [9, 0];
    # anything else (blank, "25:00", "abc") becomes nil.
    def parse(value)
      text = value.to_s.strip
      match = text.match(/\A(\d{1,2}):?(\d{2})?\z/)
      return nil unless match

      hour = match[1].to_i
      minute = match[2].to_i
      return nil if hour > 23 || minute > 59

      [hour, minute]
    end

    # Times for an issue that runs from first_day to last_day (both inclusive).
    # Returns [start, end] or nil when the event should stay all-day.
    #
    # - No start time: all-day (an end time alone is not enough).
    # - Start time only: one hour from the start time, on the last day.
    # - End at or before the start: one hour from the start.
    #
    # to_time is called with (date, hour, minute) and returns a Time in the
    # zone the times were typed in.
    def span(first_day, last_day, start_value, end_value, &to_time)
      start_hm = parse(start_value)
      return nil unless start_hm && first_day

      last_day ||= first_day
      starts = to_time.call(first_day, *start_hm)
      end_hm = parse(end_value)
      ends = end_hm ? to_time.call(last_day, *end_hm) : to_time.call(last_day, *start_hm) + ONE_HOUR
      ends = starts + ONE_HOUR if ends <= starts
      [starts, ends]
    end
  end
end
