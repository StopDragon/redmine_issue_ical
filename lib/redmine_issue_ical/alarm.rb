# frozen_string_literal: true

module RedmineIssueIcal
  # Alarms picked in an issue custom field ("정시", "30분 전", "1일 전",
  # "끝나기 10분 전", "15 minutes before", ...) and their VALARM triggers.
  # Plain Ruby so it can be tested without a Redmine instance.
  class Alarm
    MINUTE = 60
    HOUR = 60 * MINUTE
    DAY = 24 * HOUR
    WEEK = 7 * DAY

    UNITS = {
      '분' => MINUTE, '시간' => HOUR, '일' => DAY, '주' => WEEK,
      'minute' => MINUTE, 'min' => MINUTE, 'hour' => HOUR, 'day' => DAY, 'week' => WEEK
    }.freeze
    AT_START = ['정시', '일정 시간에', '시작', '시작 시간', 'at time of event', 'at start'].freeze
    NONE = ['없음', '알림 없음', 'none', 'no alarm'].freeze
    END_WORDS = %w[끝나기 종료].freeze

    # All-day events have no time, so their alarms count from this hour on the
    # first day (start) or the last day (end): "30분 전" rings at 08:30.
    ALL_DAY_HOUR = 9

    attr_reader :related, :offset

    # related: :start or :end (nil for "no alarm"); offset: seconds,
    # negative = before.
    def initialize(related, offset)
      @related = related
      @offset = offset
    end

    # "No alarm": asks the calendar app not to add its default alarm.
    def self.none
      new(nil, 0)
    end

    def none?
      related.nil?
    end

    # Alarm for a label, Alarm.none for "없음" / "none", or nil when the
    # label is not an alarm ("", "soon").
    def self.parse(label)
      text = label.to_s.strip.downcase.gsub(/\s+/, ' ')
      return nil if text.empty?
      return none if NONE.include?(text)
      return new(:start, 0) if AT_START.include?(text)

      related = :start
      words = text.split(' ')
      if END_WORDS.include?(words.first) || text.end_with?('before end')
        related = :end
        text = text.sub(/\A(#{END_WORDS.join('|')}) ?/, '').sub(/ end\z/, '')
      end
      match = text.match(/\A(\d+) ?(분|시간|일|주|minutes?|mins?|hours?|days?|weeks?) ?(전|before)\z/)
      return nil unless match

      new(related, -match[1].to_i * UNITS.fetch(match[2].sub(/s\z/, '')))
    end

    # TRIGGER property for a timed event, or an all-day event
    # (DTSTART at 00:00 of the first day, DTEND at 00:00 after the last day).
    def trigger(all_day:)
      seconds = offset
      if all_day
        seconds += related == :start ? ALL_DAY_HOUR * HOUR : (ALL_DAY_HOUR - 24) * HOUR
      end
      name = related == :end ? 'TRIGGER;RELATED=END' : 'TRIGGER'
      "#{name}:#{self.class.duration(seconds)}"
    end

    # RFC 5545 3.3.6 duration: -P1W, -P1D, -PT15H, PT8H30M, PT0S.
    def self.duration(seconds)
      sign = seconds.negative? ? '-' : ''
      rest = seconds.abs
      return "#{sign}P#{rest / WEEK}W" if rest.positive? && (rest % WEEK).zero?

      days, rest = rest.divmod(DAY)
      hours, rest = rest.divmod(HOUR)
      minutes, secs = rest.divmod(MINUTE)
      time = +''
      time << "#{hours}H" if hours.positive?
      time << "#{minutes}M" if minutes.positive?
      time << "#{secs}S" if secs.positive?
      time = '0S' if time.empty? && days.zero?
      "#{sign}P#{"#{days}D" if days.positive?}#{"T#{time}" unless time.empty?}"
    end

    def ==(other)
      other.is_a?(Alarm) && other.related == related && other.offset == offset
    end
    alias eql? ==

    def hash
      [related, offset].hash
    end
  end
end
