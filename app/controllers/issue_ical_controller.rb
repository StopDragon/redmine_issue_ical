# frozen_string_literal: true

# Serves issues as an iCalendar feed:
#   /issue_ical/my.ics?key=ATOM_KEY                  issues assigned to me (or my groups),
#                                                     plus watched issues if I chose so
#   /projects/:project_id/issue_ical.ics?key=ATOM_KEY issues of a project
#
# Either feed takes an optional tracker_id=N to list only issues of that
# tracker, so each tracker can be subscribed to as its own calendar.
#
# How issue status is shown (check mark, O/X, status name, nothing) and
# whether closed issues are left out follow the user's preference
# (My account > Preferences).
#
# Issues get a start and end time and a location when the administrator
# picked the custom fields holding them (Administration > Plugins >
# Configure); without a start time they are all-day events. Issues of a
# priority above the default one show as busy, the others as free. When a
# project custom field is picked as the client, event titles read
# "<client>-<subject>(#<id>)" instead of "[<project>] <tracker> #<id>: <subject>".
#
# Calendar apps cannot log in, so the feed accepts the user's Atom access key,
# the same key Redmine uses for its Atom feeds. Results go through
# Issue.visible, so the feed never shows more than the user can see in Redmine.
class IssueIcalController < ApplicationController
  MAX_ISSUES = 2000

  before_action :require_login
  before_action :find_feed_project
  before_action :find_feed_tracker

  def self.max_issues
    MAX_ISSUES
  end

  def index
    issues = feed_scope.limit(self.class.max_issues).to_a
    values = field_values(issues)
    @clients = client_names(issues)
    calendar = RedmineIssueIcal::CalendarBuilder.new(name: calendar_name)
                                                .build(issues.map { |issue| to_event(issue, values[issue.id]) })
    send_data calendar,
              type: 'text/calendar; charset=utf-8',
              disposition: 'inline',
              filename: feed_filename
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

  def find_feed_tracker
    return if params[:tracker_id].blank?

    @tracker = Tracker.visible.find(params[:tracker_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def feed_filename
    name = @project ? "#{@project.identifier}-issues" : 'my-issues'
    name += "-tracker-#{@tracker.id}" if @tracker
    "#{name}.ics"
  end

  def feed_scope
    table = Issue.table_name
    scope = Issue.visible
                 .where("#{table}.start_date IS NOT NULL OR #{table}.due_date IS NOT NULL")
                 .preload(:project, :tracker, :status, :priority, :assigned_to)
                 .order("#{table}.id DESC") # over the cap, the oldest issues are left out
    scope = scope.open if User.current.pref.issue_ical_hide_closed?
    scope = scope.where(tracker_id: @tracker.id) if @tracker
    if @project
      scope.where(@project.project_condition(Setting.display_subprojects_issues?))
    else
      principal_ids = [User.current.id] + User.current.group_ids
      if User.current.pref.issue_ical_watched
        watched = Watcher.where(watchable_type: 'Issue', user_id: principal_ids).select(:watchable_id)
        scope.where(assigned_to_id: principal_ids).or(scope.where(id: watched))
      else
        scope.where(assigned_to_id: principal_ids)
      end
    end
  end

  # Default name calendar apps show when subscribing, in the user's language:
  # "Issues" / "일감" for the personal feed, "Issues of <project>" for a project,
  # followed by " - <tracker>" for a single-tracker feed.
  def calendar_name
    name =
      if @project
        l(:label_issue_ical_project_issues, project: @project.name)
      else
        l(:label_issue_plural)
      end
    @tracker ? "#{name} - #{@tracker.name}" : name
  end

  def to_event(issue, values)
    values ||= {}
    starts, ends = event_span(issue, values['start_time_field_id'], values['end_time_field_id'])
    RedmineIssueIcal::CalendarBuilder::Event.new(
      start_at: starts,
      end_at: ends,
      location: values['location_field_id'],
      busy: !starts.nil? && busy?(issue),
      uid: "redmine-issue-#{issue.id}@#{request.host}",
      summary: summary_for(issue),
      description: description_for(issue),
      url: issue_url(issue),
      start_date: issue.start_date,
      due_date: issue.due_date,
      updated_at: issue.updated_on
    )
  end

  def plugin_settings
    Setting.plugin_redmine_issue_ical || {}
  end

  FIELD_SETTINGS = %w[start_time_field_id end_time_field_id location_field_id].freeze

  # { setting name => custom field } for the fields the administrator picked.
  def picked_fields
    @picked_fields ||= begin
      ids = FIELD_SETTINGS.to_h { |key| [key, plugin_settings[key].to_s] }.reject { |_, id| id == '' }
      fields = IssueCustomField.where(id: ids.values).index_by { |field| field.id.to_s }
      ids.transform_values { |id| fields[id] }.compact
    end
  end

  # { issue_id => { setting name => value } } in one query. As on the issue
  # page, a value is left out when the field is not enabled for the issue's
  # project and tracker, or the user may not see it in that project.
  def field_values(issues)
    picked = picked_fields
    return {} if picked.empty? || issues.empty?

    issues_by_id = issues.index_by(&:id)
    fields_by_id = picked.values.index_by(&:id)
    values = Hash.new { |hash, key| hash[key] = {} }
    visible = Hash.new { |hash, (field, project)| hash[[field, project]] = field.visible_by?(project, User.current) }
    available = Hash.new do |hash, (project, tracker)|
      hash[[project, tracker]] = (project.all_issue_custom_fields & tracker.custom_fields).map(&:id)
    end
    CustomValue.where(customized_type: 'Issue', customized_id: issues_by_id.keys, custom_field_id: fields_by_id.keys)
               .pluck(:customized_id, :custom_field_id, :value).each do |issue_id, field_id, value|
      field = fields_by_id[field_id]
      issue = issues_by_id[issue_id]
      next unless available[[issue.project, issue.tracker]].include?(field_id)
      next unless visible[[field, issue.project]]

      picked.each { |key, picked_field| values[issue_id][key] = value if picked_field == field }
    end
    values
  end

  # Timed events of a priority above the default one (in a stock Redmine:
  # High, Urgent and Immediate) block time in the calendar. All-day events
  # never do, so a long issue does not make its assignee busy for weeks. Same rule as IssuePriority#high?,
  # with the baseline looked up once per feed.
  def busy?(issue)
    @baseline_priority = IssuePriority.default_or_middle&.position unless defined?(@baseline_priority)
    !@baseline_priority.nil? && issue.priority.position.to_i > @baseline_priority
  end

  def event_span(issue, start_value, end_value)
    return nil if start_value.to_s.strip == ''

    range = RedmineIssueIcal::CalendarBuilder.date_range(issue.start_date, issue.due_date)
    return nil unless range

    zone = time_zone
    RedmineIssueIcal::EventTime.span(range[0], range[1] - 1, start_value, end_value) do |date, hour, minute|
      zone ? zone.local(date.year, date.month, date.day, hour, minute) : Time.local(date.year, date.month, date.day, hour, minute)
    end
  rescue StandardError => e
    Rails.logger.warn("redmine_issue_ical: issue ##{issue.id} kept all-day: #{e.class}: #{e.message}")
    nil
  end

  # Times are read in the user's time zone, then the zone set for the plugin,
  # then the server's zone.
  def time_zone
    return @time_zone if defined?(@time_zone)

    name = plugin_settings['time_zone'].to_s
    @time_zone = User.current.time_zone || (name == '' ? nil : ActiveSupport::TimeZone[name])
  end

  CHECK_MARK = "\u2714 "

  def summary_for(issue)
    return status_prefix(issue) + "[#{issue.project.name}] #{issue.tracker.name} ##{issue.id}: #{issue.subject}" unless client_field

    client = @clients[issue.project_id].to_s.strip
    title = "#{issue.subject}(##{issue.id})"
    status_prefix(issue) + (client.empty? ? title : "#{client}-#{title}")
  end

  # The project custom field the administrator picked as the client.
  def client_field
    return @client_field if defined?(@client_field)

    id = plugin_settings['client_field_id'].to_s
    @client_field = id == '' ? nil : ProjectCustomField.find_by(id: id)
  end

  # { project_id => client } in one query, for the projects whose client
  # field the user may see.
  def client_names(issues)
    field = client_field
    return {} unless field && issues.any?

    projects = issues.map(&:project).uniq.select { |project| field.visible_by?(project, User.current) }
    CustomValue.where(customized_type: 'Project', customized_id: projects.map(&:id), custom_field_id: field.id)
               .where.not(value: [nil, '']).order(:id).pluck(:customized_id, :value)
               .group_by(&:first).transform_values { |rows| rows.map(&:last).join(', ') }
  end

  def status_prefix(issue)
    case User.current.pref.issue_ical_closed
    when 'mark' then issue.closed? ? CHECK_MARK : ''
    when 'ox' then issue.closed? ? 'O ' : 'X '
    when 'status' then "[#{issue.status.name}] "
    else ''
    end
  end

  DESCRIPTION_LIMIT = 1000 # characters of the issue's own description

  # The issue's own description first, then a blank line and the summary.
  def description_for(issue)
    summary = [
      "#{l(:field_status)}: #{issue.status.name}",
      "#{l(:field_priority)}: #{issue.priority.name}",
      "#{l(:field_assigned_to)}: #{issue.assigned_to&.name || '-'}",
      "#{l(:field_done_ratio)}: #{issue.done_ratio}%"
    ].join("\n")
    text = plain_text(issue)
    return summary if text.empty?

    text = "#{text[0, DESCRIPTION_LIMIT].rstrip}\u2026" if text.length > DESCRIPTION_LIMIT
    "#{text}\n\n#{summary}"
  end

  # Renders the description with the site's text formatting (Textile /
  # Markdown) and reads the HTML back as plain text, so calendar apps show no
  # markup. Redmine links and macros (#123, [[Page]], {{toc}}) are left as
  # written. Only the start is rendered, since only DESCRIPTION_LIMIT
  # characters are kept, and the HTML goes through Redmine's formatted text
  # cache when that is turned on.
  def plain_text(issue)
    text = issue.description.to_s.gsub(/\r\n?/, "\n").strip
    return text if text.empty?

    text = text[0, DESCRIPTION_LIMIT * 3]
    html = Redmine::WikiFormatting.to_html(Setting.text_formatting, text, object: issue, attribute: :description)
    Redmine::WikiFormatting::HtmlParser.to_text(keep_pre_line_breaks(html)).strip
  rescue StandardError => e
    Rails.logger.warn("redmine_issue_ical: could not strip markup: #{e.class}: #{e.message}")
    text.to_s
  end

  # HtmlParser.to_text turns every newline into a space; inside code blocks
  # the line breaks matter, so they become <br> first.
  def keep_pre_line_breaks(html)
    html.gsub(%r{<pre\b[^>]*>.*?</pre>}m) { |pre| pre.gsub(/\r?\n/, '<br>') }
  end
end
