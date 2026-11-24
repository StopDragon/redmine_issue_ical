# frozen_string_literal: true

module RedmineIssueIcal
  # Per-user choice of how the feeds show issue status, stored in the
  # user's preferences (no database migration needed).
  #   mark   - closed issues get a check mark (default)
  #   ox     - closed issues get "O", open issues get "X"
  #   status - every issue gets its status name, e.g. "[In Progress]"
  #   plain  - no marker; closed issues stay as they are
  #   hide   - no marker; closed issues are left out
  # The preference key keeps its 0.3.0 name so saved choices carry over.
  module UserPreferencePatch
    CLOSED_OPTIONS = %w[mark ox status plain hide].freeze
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
