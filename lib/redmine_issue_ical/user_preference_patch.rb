# frozen_string_literal: true

module RedmineIssueIcal
  # Per-user choice of what the feeds do with closed issues, stored in the
  # user's preferences (no database migration needed).
  #   mark - keep closed issues and prefix their title with a check mark (default)
  #   hide - leave closed issues out
  module UserPreferencePatch
    CLOSED_OPTIONS = %w[mark hide].freeze
    CLOSED_DEFAULT = 'mark'

    def issue_ical_closed
      value = self[:issue_ical_closed].to_s
      CLOSED_OPTIONS.include?(value) ? value : CLOSED_DEFAULT
    end

    def issue_ical_closed=(value)
      self[:issue_ical_closed] = CLOSED_OPTIONS.include?(value.to_s) ? value.to_s : CLOSED_DEFAULT
    end

    def issue_ical_hide_closed?
      issue_ical_closed == 'hide'
    end
  end
end
