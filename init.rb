# frozen_string_literal: true

# Redmine Issue iCal - subscribe to Redmine issues as an iCalendar feed
# Copyright (C) 2026 StopDragon
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

Redmine::Plugin.register :redmine_issue_ical do
  name 'Redmine Issue iCal'
  author 'StopDragon'
  description 'Subscribe to issue start and due dates from any calendar app (iCalendar / .ics feed).'
  version '0.5.0'
  url 'https://github.com/StopDragon/redmine_issue_ical'
  requires_redmine version_or_higher: '7.0.0'
end

# Hooks register themselves when the class is loaded.
RedmineIssueIcal::Hooks

unless UserPreference.included_modules.include?(RedmineIssueIcal::UserPreferencePatch)
  UserPreference.include RedmineIssueIcal::UserPreferencePatch
end
UserPreference.safe_attributes 'issue_ical_closed', 'issue_ical_watched'
