# frozen_string_literal: true

module RedmineIssueIcal
  # When the start and end time fields are set up in the plugin settings, an
  # issue with only one of the two times cannot be saved: the calendar needs
  # both to place a timed event.
  #
  # The check runs only when a time was entered or changed, so older issues
  # that already have a single time can still be edited for other reasons
  # (status, assignee, bulk edit) until someone touches their times. It is
  # skipped when the fields are not enabled for the issue's project and
  # tracker, or when the user may not edit the missing one (workflow).
  module IssuePatch
    def self.included(base)
      base.validate :validate_issue_ical_time_pair
    end

    private

    def validate_issue_ical_time_pair
      start_value, end_value = issue_ical_time_values
      return unless start_value && end_value

      filled = [start_value, end_value].map { |value| value.value.to_s.strip != '' }
      return unless filled.one?
      return unless [start_value, end_value].any? { |value| value.value.to_s != value.value_was.to_s }

      missing, given = filled.first ? [end_value, start_value] : [start_value, end_value]
      return unless editable_custom_field_values.include?(missing)

      errors.add(:base, ::I18n.t(:error_issue_ical_time_pair,
                                 missing: missing.custom_field.name, given: given.custom_field.name))
    end

    # The custom field values of the start and end time fields, or nil.
    def issue_ical_time_values
      settings = Setting.plugin_redmine_issue_ical || {}
      ids = [settings['start_time_field_id'], settings['end_time_field_id']].map(&:to_s)
      return [] if ids.any?(&:empty?) || ids.uniq.size < 2

      ids.map { |id| custom_field_values.detect { |value| value.custom_field.id.to_s == id } }
    end
  end
end
