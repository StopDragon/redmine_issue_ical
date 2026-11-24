# frozen_string_literal: true

module RedmineIssueIcal
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_my_account_contextual, partial: 'issue_ical/my_account_link'
    render_on :view_issues_sidebar_queries_bottom, partial: 'issue_ical/sidebar'
  end
end
