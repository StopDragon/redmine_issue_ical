# frozen_string_literal: true

require 'date'

module RedmineIssueIcal
  # Builds an RFC 5545 calendar with one all-day event per issue.
  # Plain Ruby so it can be tested without a Redmine instance.
  class CalendarBuilder
    Event = Struct.new(:uid, :summary, :description, :url, :start_date, :due_date, :updated_at,
                       keyword_init: true)

    PRODID = '-//redmine_issue_ical//Redmine Issue iCal//EN'
    LINE_LIMIT = 75 # octets, excluding CRLF (RFC 5545 3.1)

    def initialize(name:, now: Time.now)
      @name = name
      @now = now
    end

    def build(events)
      lines = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        "PRODID:#{PRODID}",
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        "X-WR-CALNAME:#{escape(@name)}",
        'REFRESH-INTERVAL;VALUE=DURATION:PT1H',
        'X-PUBLISHED-TTL:PT1H'
      ]
      events.each { |event| lines.concat(event_lines(event)) }
      lines << 'END:VCALENDAR'
      lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
    end

    # All-day span from the start date to the due date, either one standing in
    # for the other. DTEND is exclusive, so it is the day after the last day.
    def self.date_range(start_date, due_date)
      first = start_date || due_date
      last = due_date || start_date
      return nil unless first

      last = first if last < first
      [first, last + 1]
    end

    private

    def event_lines(event)
      range = self.class.date_range(event.start_date, event.due_date)
      return [] unless range

      lines = [
        'BEGIN:VEVENT',
        "UID:#{escape(event.uid)}",
        "DTSTAMP:#{utc(@now)}",
        "DTSTART;VALUE=DATE:#{range[0].strftime('%Y%m%d')}",
        "DTEND;VALUE=DATE:#{range[1].strftime('%Y%m%d')}",
        "SUMMARY:#{escape(event.summary)}",
        'TRANSP:TRANSPARENT'
      ]
      lines << "LAST-MODIFIED:#{utc(event.updated_at)}" if event.updated_at
      lines << "DESCRIPTION:#{escape(event.description)}" if event.description.to_s != ''
      lines << "URL:#{event.url}" if event.url.to_s != ''
      lines << 'END:VEVENT'
    end

    def utc(time)
      time.utc.strftime('%Y%m%dT%H%M%SZ')
    end

    # RFC 5545 3.3.11 TEXT escaping.
    def escape(text)
      text.to_s
          .gsub(/[\\;,]/) { |char| "\\#{char}" }
          .gsub(/\r\n|\r|\n/) { '\\n' }
    end

    # Fold lines longer than 75 octets without splitting a multibyte character.
    def fold(line)
      return line if line.bytesize <= LINE_LIMIT

      parts = []
      current = +''
      limit = LINE_LIMIT
      line.each_char do |char|
        if current.bytesize + char.bytesize > limit
          parts << current
          current = +''
          limit = LINE_LIMIT - 1 # continuation lines start with a space
        end
        current << char
      end
      parts << current
      parts.join("\r\n ")
    end
  end
end
