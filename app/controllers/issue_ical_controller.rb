# frozen_string_literal: true

# Serves issues as an iCalendar feed:
#   /issue_ical/my.ics?key=ATOM_KEY                  issues assigned to me (or my groups)
#   /projects/:project_id/issue_ical.ics?key=ATOM_KEY issues of a project
#
# How issue status is shown (check mark, O/X, status name, nothing) and
# whether closed issues are left out follow the user's preference
# (My account > Preferences).
#
# Calendar apps cannot log in, so the feed accepts the user's Atom access key,
# the same key Redmine uses for its Atom feeds. Results go through
# Issue.visible, so the feed never shows more than the user can see in Redmine.
class IssueIcalController < ApplicationController
  MAX_ISSUES = 2000

  before_action :require_login
  before_action :find_feed_project

  def self.max_issues
    MAX_ISSUES
  end

  def index
    issues = feed_scope.limit(self.class.max_issues).to_a
    calendar = RedmineIssueIcal::CalendarBuilder.new(name: calendar_name)
                                                .build(issues.map { |issue| to_event(issue) })
    send_data calendar,
              type: 'text/calendar; charset=utf-8',
              disposition: 'inline',
              filename: @project ? "#{@project.identifier}-issues.ics" : 'my-issues.ics'
  end

  private

  # Accept the Atom key for this feed. ApplicationController only does that
  # for the atom format, so the ics format is handled here. HEAD is accepted
  # too because some calendar clients probe the URL with HEAD first.
  def find_current_user
    if (request.get? || request.head?) && params[:format] == 'ics' && params[:key].present?
      user = User.find_by_atom_key(params[:key])
      if user
        user.remote_ip = request.remote_ip
        return user
      end
    end
    super
  end

  def find_feed_project
    return unless params[:project_id]

    @project = Project.find(params[:project_id])
    deny_access unless User.current.allowed_to?(:view_issues, @project)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def feed_scope
    table = Issue.table_name
    scope = Issue.visible
                 .where("#{table}.start_date IS NOT NULL OR #{table}.due_date IS NOT NULL")
                 .preload(:project, :tracker, :status, :priority, :assigned_to)
                 .order("#{table}.id DESC") # over the cap, the oldest issues are left out
    scope = scope.open if User.current.pref.issue_ical_hide_closed?
    if @project
      scope.where(@project.project_condition(Setting.display_subprojects_issues?))
    else
      scope.where(assigned_to_id: [User.current.id] + User.current.group_ids)
    end
  end

  def calendar_name
    if @project
      "#{Setting.app_title} - #{@project.name}"
    else
      "#{Setting.app_title} - #{l(:label_issue_ical_my_issues)}"
    end
  end

  def to_event(issue)
    RedmineIssueIcal::CalendarBuilder::Event.new(
      uid: "redmine-issue-#{issue.id}@#{request.host}",
      summary: summary_for(issue),
      description: description_for(issue),
      url: issue_url(issue),
      start_date: issue.start_date,
      due_date: issue.due_date,
      updated_at: issue.updated_on
    )
  end

  CHECK_MARK = "\u2714 "

  def summary_for(issue)
    status_prefix(issue) + "[#{issue.project.name}] #{issue.tracker.name} ##{issue.id}: #{issue.subject}"
  end

  def status_prefix(issue)
    case User.current.pref.issue_ical_closed
    when 'mark' then issue.closed? ? CHECK_MARK : ''
    when 'ox' then issue.closed? ? 'O ' : 'X '
    when 'status' then "[#{issue.status.name}] "
    else ''
    end
  end

  def description_for(issue)
    lines = [
      "#{l(:field_status)}: #{issue.status.name}",
      "#{l(:field_priority)}: #{issue.priority.name}",
      "#{l(:field_assigned_to)}: #{issue.assigned_to&.name || '-'}",
      "#{l(:field_done_ratio)}: #{issue.done_ratio}%"
    ]
    lines << issue_url(issue)
    lines.join("\n")
  end
end
