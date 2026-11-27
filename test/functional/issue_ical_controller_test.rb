# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class IssueIcalControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :projects_trackers, :enabled_modules,
           :enumerations, :issue_categories, :versions, :tokens, :groups_users, :watchers

  def setup
    User.current = nil
    Setting.default_language = 'en'
    # Issue 4: project 2 (private), assigned to jsmith
    Issue.find(4).update_columns(start_date: Date.new(2026, 12, 1), due_date: Date.new(2026, 12, 3))
  end

  def feed_body(params)
    get :index, params: { format: 'ics' }.merge(params)
    assert_response :success
    assert_equal 'text/calendar', response.media_type
    response.body
  end

  test 'my feed with the atom key lists issues assigned to the user' do
    body = feed_body(key: User.find(2).atom_key)
    assert_includes body, "X-WR-CALNAME:Issues\r\n"
    assert_includes body, 'UID:redmine-issue-4@'
    assert_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
    assert_includes body, "DTEND;VALUE=DATE:20261204\r\n"
    assert_not_includes body, 'UID:redmine-issue-3@' # assigned to dlopper
  end

  test 'my feed includes issues assigned to a group of the user' do
    group = Group.find(10)
    user = group.users.first
    Issue.find(1).update_columns(assigned_to_id: group.id)
    body = feed_body(key: user.atom_key)
    assert_includes body, 'UID:redmine-issue-1@'
  end

  test 'closed issues are kept with a check mark by default' do
    Issue.find(3).update_columns(status_id: 5)
    body = feed_body(key: User.find(3).atom_key).gsub("\r\n ", '')
    assert_includes body, 'UID:redmine-issue-2@'
    assert_match(/SUMMARY:\u2714 \[eCookbook\] [^\r]*#3:/, body)
    assert_no_match(/SUMMARY:\u2714 [^\r]*#2:/, body)
  end

  def summaries_with(option)
    Issue.find(3).update_columns(status_id: 5)
    user = User.find(3)
    user.pref.issue_ical_closed = option
    user.pref.save!
    body = feed_body(key: user.atom_key).gsub("\r\n ", '')
    {
      open: body[/^SUMMARY:.*#2:.*$/],
      closed: body[/^SUMMARY:.*#3:.*$/]
    }
  end

  test 'ox option marks closed issues with O and open issues with X' do
    s = summaries_with('ox')
    assert s[:closed].start_with?('SUMMARY:O [eCookbook]'), s[:closed]
    assert s[:open].start_with?('SUMMARY:X [eCookbook]'), s[:open]
  end

  test 'status option prefixes every issue with its status name' do
    s = summaries_with('status')
    assert s[:closed].start_with?('SUMMARY:[Closed] [eCookbook]'), s[:closed]
    assert s[:open].start_with?('SUMMARY:[Assigned] [eCookbook]'), s[:open]
  end

  test 'plain option keeps closed issues without any marker' do
    s = summaries_with('plain')
    assert s[:closed].start_with?('SUMMARY:[eCookbook]'), s[:closed]
    assert s[:open].start_with?('SUMMARY:[eCookbook]'), s[:open]
  end

  test 'mark option only marks closed issues' do
    s = summaries_with('mark')
    assert s[:closed].start_with?("SUMMARY:\u2714 [eCookbook]"), s[:closed]
    assert s[:open].start_with?('SUMMARY:[eCookbook]'), s[:open]
  end

  test 'closed issues are left out when the user chose to hide them' do
    Issue.find(3).update_columns(status_id: 5)
    user = User.find(3)
    user.pref.issue_ical_closed = 'hide'
    user.pref.save!
    body = feed_body(key: user.atom_key)
    assert_includes body, 'UID:redmine-issue-2@'
    assert_not_includes body, 'UID:redmine-issue-3@'
  end

  test 'project feed follows the preference of the subscribing user' do
    Issue.find(3).update_columns(status_id: 5)
    user = User.find(2)
    user.pref.issue_ical_closed = 'hide'
    user.pref.save!
    body = feed_body(project_id: 'ecookbook', key: user.atom_key)
    assert_includes body, 'UID:redmine-issue-1@'
    assert_not_includes body, 'UID:redmine-issue-3@'
  end

  test 'my feed leaves out issues the user can no longer see' do
    Issue.find(4).update_columns(assigned_to_id: 3) # dlopper is not a member of project 2
    body = feed_body(key: User.find(3).atom_key)
    assert_not_includes body, 'UID:redmine-issue-4@'
  end

  test 'calendar name follows the user language' do
    user = User.find(2)
    user.update_column(:language, 'ko')
    body = feed_body(key: user.atom_key)
    assert_includes body, "X-WR-CALNAME:\uC77C\uAC10\r\n" # 일감
  end

  test 'watched issues are not in my feed by default' do
    Watcher.find_or_create_by!(watchable: Issue.find(1), user: User.find(2))
    body = feed_body(key: User.find(2).atom_key)
    assert_not_includes body, 'UID:redmine-issue-1@'
  end

  test 'watched issues are in my feed when the user chose so' do
    Watcher.find_or_create_by!(watchable: Issue.find(1), user: User.find(2))
    user = User.find(2)
    user.pref.issue_ical_watched = '1'
    user.pref.save!
    body = feed_body(key: user.atom_key)
    assert_includes body, 'UID:redmine-issue-1@' # watched
    assert_includes body, 'UID:redmine-issue-4@' # still assigned
    assert_not_includes body, 'UID:redmine-issue-3@' # neither
  end

  test 'watched issues the user can no longer see stay out' do
    Watcher.find_or_create_by!(watchable: Issue.find(4), user: User.find(3)) # project 2, dlopper is not a member
    user = User.find(3)
    user.pref.issue_ical_watched = '1'
    user.pref.save!
    body = feed_body(key: user.atom_key)
    assert_not_includes body, 'UID:redmine-issue-4@'
  end

  test 'my feed can be limited to one tracker' do
    body = feed_body(key: User.find(3).atom_key, tracker_id: 1)
    assert_includes body, 'UID:redmine-issue-3@' # Bug
    assert_not_includes body, 'UID:redmine-issue-2@' # Feature request
    assert_includes body, "X-WR-CALNAME:Issues - Bug\r\n"
    assert_match(/filename="my-issues-tracker-1\.ics"/, response.headers['Content-Disposition'])
  end

  test 'project feed can be limited to one tracker' do
    body = feed_body(project_id: 'ecookbook', key: User.find(2).atom_key, tracker_id: 2)
    assert_includes body, 'UID:redmine-issue-2@' # Feature request
    assert_not_includes body, 'UID:redmine-issue-1@' # Bug
    assert_not_includes body, 'UID:redmine-issue-3@' # Bug
    assert_includes body, 'X-WR-CALNAME:Issues of eCookbook - Feature request'
  end

  test 'feed returns 404 for an unknown tracker' do
    get :index, params: { format: 'ics', key: User.find(2).atom_key, tracker_id: 999 }
    assert_response :not_found
  end

  test 'feed without a key requires login' do
    get :index, params: { format: 'ics' }
    assert_response :unauthorized
  end

  test 'feed with an unknown key requires login' do
    get :index, params: { format: 'ics', key: 'not-a-real-key' }
    assert_response :unauthorized
  end

  test 'feed refuses the key of a locked user' do
    user = User.find(2)
    key = user.atom_key
    user.lock!
    get :index, params: { format: 'ics', key: key }
    assert_response :unauthorized
  end

  test 'project feed lists open issues of the project' do
    body = feed_body(project_id: 'ecookbook', key: User.find(2).atom_key)
    assert_includes body, 'UID:redmine-issue-1@'
    assert_includes body, 'UID:redmine-issue-3@'
    assert_not_includes body, 'UID:redmine-issue-4@' # other project
    assert_includes body, 'X-WR-CALNAME:Issues of eCookbook'
  end

  test 'project feed is denied without view_issues permission' do
    get :index, params: { format: 'ics', project_id: 'onlinestore', key: User.find(3).atom_key }
    assert_response :forbidden
  end

  test 'project feed returns 404 for an unknown project' do
    get :index, params: { format: 'ics', project_id: 'no-such-project', key: User.find(2).atom_key }
    assert_response :not_found
  end

  test 'issue url and description are included' do
    Issue.find(4).update_columns(description: '')
    body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
    assert_includes body, 'URL:http://test.host/issues/4'
    assert_includes body, 'DESCRIPTION:Status: New\\nPriority: '
    description = body[/^DESCRIPTION:.*$/]
    assert_not_includes description, '/issues/'
  end

  test 'the issue description comes first, then a blank line and the summary' do
    Issue.find(4).update_columns(description: "First line\r\nSecond line\r\n")
    body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
    assert_includes body, 'DESCRIPTION:First line\\nSecond line\\n\\nStatus: New\\nPriority: '
  end

  test 'markup is removed from the issue description' do
    with_settings text_formatting: 'textile' do
      Issue.find(4).update_columns(description: "h2. Heading\r\n\r\nSome *bold* and _italic_ text")
      body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
      description = body[/^DESCRIPTION:.*$/]
      assert_includes description, 'Heading'
      assert_includes description, 'Some bold and italic text'
      assert_not_includes description, 'h2.'
      assert_not_includes description, '*'
    end
  end

  test 'a long issue description is cut off' do
    Issue.find(4).update_columns(description: 'a' * 1500)
    body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
    assert_includes body, "DESCRIPTION:#{'a' * 1000}\u2026\\n\\nStatus: "
    assert_not_includes body, 'a' * 1001
  end

  test 'over the cap, the newest issues are kept' do
    IssueIcalController.stubs(:max_issues).returns(1)
    body = feed_body(project_id: 'ecookbook', key: User.find(2).atom_key)
    assert_equal 1, body.scan('BEGIN:VEVENT').size
    newest = Issue.visible(User.find(2)).where(project_id: [1, 3, 4, 5, 6])
                  .where('start_date IS NOT NULL OR due_date IS NOT NULL').maximum(:id)
    assert_includes body, "UID:redmine-issue-#{newest}@"
  end

  test 'HEAD request with the atom key succeeds' do
    head :index, params: { format: 'ics', key: User.find(2).atom_key }
    assert_response :success
  end

  test 'atom key does not start a session' do
    feed_body(key: User.find(2).atom_key)
    assert_nil session[:user_id]
  end

  def time_field(name, visible: true)
    IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true, visible: visible,
                             role_ids: visible ? [] : [Role.create!(name: "Nobody #{name}").id], tracker_ids: Tracker.pluck(:id))
  end

  # Issue 4 runs from 2026-12-01 to 2026-12-03 (see setup).
  def with_time_fields(start_value, end_value, visible: true, zone: '')
    start_field = time_field('Start time', visible: visible)
    end_field = time_field('End time', visible: visible)
    CustomValue.create!(customized: Issue.find(4), custom_field: start_field, value: start_value)
    CustomValue.create!(customized: Issue.find(4), custom_field: end_field, value: end_value)
    settings = { 'start_time_field_id' => start_field.id.to_s, 'end_time_field_id' => end_field.id.to_s,
                 'time_zone' => zone }
    with_settings(plugin_redmine_issue_ical: settings) { yield }
  end

  def set_user_time_zone(zone)
    pref = User.find(2).pref
    pref.time_zone = zone
    pref.save!
  end

  test 'issues with a start and end time become timed events in UTC' do
    set_user_time_zone('Seoul')
    with_time_fields('09:30', '1800') do
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "DTSTART:20261201T003000Z\r\n"
      assert_includes body, "DTEND:20261203T090000Z\r\n"
      assert_not_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
    end
  end

  test 'the plugin time zone is used when the user has none' do
    set_user_time_zone('')
    with_time_fields('09:30', '18:00', zone: 'Tokyo') do
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "DTSTART:20261201T003000Z\r\n"
    end
  end

  test 'a time field the user may not see is not used' do
    set_user_time_zone('Seoul')
    with_time_fields('09:30', '18:00', visible: false) do
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
      assert_not_includes body, 'DTSTART:2026'
    end
  end

  test 'the location field becomes the event location' do
    field = time_field('Location')
    CustomValue.create!(customized: Issue.find(4), custom_field: field, value: 'Room 3')
    with_settings(plugin_redmine_issue_ical: { 'location_field_id' => field.id.to_s }) do
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "LOCATION:Room 3\r\n"
      assert_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
    end
  end

  test 'timed issues above the default priority are busy, the others free' do
    default = IssuePriority.default_or_middle
    high = IssuePriority.active.detect { |priority| priority.position > default.position }
    set_user_time_zone('Seoul')
    with_time_fields('09:30', '18:00') do
      Issue.find(4).update_columns(priority_id: high.id)
      assert_includes feed_body(key: User.find(2).atom_key), "TRANSP:OPAQUE\r\n"

      Issue.find(4).update_columns(priority_id: default.id)
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "TRANSP:TRANSPARENT\r\n"
      assert_not_includes body, 'TRANSP:OPAQUE'
    end
  end

  test 'all-day issues stay free whatever the priority' do
    default = IssuePriority.default_or_middle
    high = IssuePriority.active.detect { |priority| priority.position > default.position }
    Issue.find(4).update_columns(priority_id: high.id)
    body = feed_body(key: User.find(2).atom_key)
    assert_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
    assert_not_includes body, 'TRANSP:OPAQUE'
  end

  test 'a field not enabled for the issue project is not used' do
    field = IssueCustomField.create!(name: 'Location', field_format: 'string', is_for_all: false,
                                     project_ids: [1], tracker_ids: Tracker.pluck(:id))
    CustomValue.create!(customized: Issue.find(4), custom_field: field, value: 'Old room') # issue 4 is in project 2
    with_settings(plugin_redmine_issue_ical: { 'location_field_id' => field.id.to_s }) do
      assert_not_includes feed_body(key: User.find(2).atom_key), 'LOCATION:'
    end
  end

  test 'a field not enabled for the issue tracker is not used' do
    issue = Issue.find(4)
    field = IssueCustomField.create!(name: 'Location', field_format: 'string', is_for_all: true,
                                     tracker_ids: Tracker.where.not(id: issue.tracker_id).pluck(:id))
    CustomValue.create!(customized: issue, custom_field: field, value: 'Old room')
    with_settings(plugin_redmine_issue_ical: { 'location_field_id' => field.id.to_s }) do
      assert_not_includes feed_body(key: User.find(2).atom_key), 'LOCATION:'
    end
  end

  test 'code blocks in the description keep their line breaks' do
    with_settings text_formatting: 'common_mark' do
      Issue.find(4).update_columns(description: "Log:\r\n\r\n```\r\nline one\r\nline two\r\n```\r\n")
      body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
      assert_includes body[/^DESCRIPTION:.*$/], 'line one\\nline two'
    end
  end

  def client_field
    ProjectCustomField.create!(name: 'Client', field_format: 'string', visible: true)
  end

  def summary_of_issue4
    feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')[/^SUMMARY:[^\r\n]*#4\)/]
  end

  test 'with a client field the title is client-subject(#id)' do
    field = client_field
    CustomValue.create!(customized: Project.find(2), custom_field: field, value: 'Hi-M')
    with_settings(plugin_redmine_issue_ical: { 'client_field_id' => field.id.to_s }) do
      assert_equal "SUMMARY:Hi-M-#{Issue.find(4).subject}(#4)", summary_of_issue4
    end
  end

  test 'without a client value the title is subject(#id)' do
    field = client_field
    with_settings(plugin_redmine_issue_ical: { 'client_field_id' => field.id.to_s }) do
      assert_equal "SUMMARY:#{Issue.find(4).subject}(#4)", summary_of_issue4
    end
  end

  test 'the status prefix still comes first with a client field' do
    field = client_field
    CustomValue.create!(customized: Project.find(2), custom_field: field, value: 'Hi-M')
    User.find(2).pref.update!(issue_ical_closed: 'ox')
    with_settings(plugin_redmine_issue_ical: { 'client_field_id' => field.id.to_s }) do
      assert summary_of_issue4.start_with?('SUMMARY:X Hi-M-'), summary_of_issue4
    end
  end

  test 'a client field the user may not see is not used' do
    field = ProjectCustomField.create!(name: 'Client', field_format: 'string', visible: false,
                                       role_ids: [Role.create!(name: 'Nobody client').id])
    CustomValue.create!(customized: Project.find(2), custom_field: field, value: 'Secret client')
    with_settings(plugin_redmine_issue_ical: { 'client_field_id' => field.id.to_s }) do
      assert_equal "SUMMARY:#{Issue.find(4).subject}(#4)", summary_of_issue4
    end
  end

  test 'an invalid start time keeps the event all-day' do
    set_user_time_zone('Seoul')
    with_time_fields('soon', '18:00') do
      body = feed_body(key: User.find(2).atom_key)
      assert_includes body, "DTSTART;VALUE=DATE:20261201\r\n"
    end
  end
end

class IssueIcalLinksTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :issues, :issue_statuses, :trackers, :projects_trackers, :enabled_modules,
           :enumerations, :issue_categories, :versions, :tokens, :queries

  test 'my account page shows a subscribe button with the personal feed url' do
    log_user('jsmith', 'jsmith')
    get '/my/account'
    assert_response :success
    assert_select 'div.contextual a.icon-issue-ical svg.icon-svg'
    assert_select '#issue-ical-modal-my input.issue-ical-url-input[value*=?]', '/issue_ical/my.ics?key='
    assert_select '#issue-ical-modal-my button.issue-ical-copy'
    assert_select '#issue-ical-modal-my a[href^=?]', 'webcal://'
    assert_select '#issue-ical-modal-my a[href^=?]', 'https://calendar.google.com/calendar/r?cid=webcal%3A%2F%2F'
    # the feed url is not a plain link, so clicking never downloads the file
    assert_select 'a[href^=?][href*=?]', 'http', 'issue_ical/my.ics', 0
  end

  test 'my account preferences show the closed issues option' do
    log_user('jsmith', 'jsmith')
    get '/my/account'
    assert_select '#issue-ical-preferences input[type=radio][name=?][value=mark][checked=checked]',
                  'pref[issue_ical_closed]'
    assert_select '#issue-ical-preferences input[type=radio][value=hide]'
    assert_select '#issue-ical-modal-my a[href$=?]', '/my/account#issue-ical-preferences'
    assert_select '#issue-ical-preferences input[type=radio]', 5
    assert_select 'input[type=checkbox]#pref_issue_ical_watched:not([checked])'
    assert_select '#issue-ical-modal-my a.issue-ical-settings-link'
  end

  test 'closed issues option is saved from my account' do
    log_user('jsmith', 'jsmith')
    put '/my/account', params: { user: { firstname: 'John' }, pref: { issue_ical_closed: 'hide', issue_ical_watched: '1' } }
    assert_redirected_to '/my/account'
    assert_equal 'hide', User.find(2).pref.issue_ical_closed
    assert User.find(2).pref.issue_ical_watched
    get '/my/account'
    assert_select '#issue-ical-preferences input[value=hide][checked=checked]'
  end

  test 'issues sidebar opens the personal and project feeds' do
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/issues'
    assert_response :success
    assert_select 'ul.issue-ical-links a', 2
    assert_select '#issue-ical-modal-my input[value*=?]', '/issue_ical/my.ics?key='
    assert_select '#issue-ical-modal-project input[value*=?]', '/projects/ecookbook/issue_ical.ics?key='
  end

  test 'subscribe dialog offers one feed per tracker' do
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/issues'
    assert_select '#issue-ical-modal-my select.issue-ical-tracker-select' do
      assert_select 'option:first-child', text: 'All trackers'
      assert_select 'option[value*=?]', 'tracker_id=1'
    end
    assert_select '#issue-ical-modal-my input.issue-ical-url-input[value*=?]', 'tracker_id', 0
    assert_select '#issue-ical-modal-project option[value*=?][data-webcal^=?]', 'tracker_id=2', 'webcal://'
  end

  test 'anonymous users see no feed links' do
    get '/projects/ecookbook/issues'
    assert_response :success
    assert_select 'ul.issue-ical-links', 0
  end

  def text_field(name)
    IssueCustomField.create!(name: name, field_format: 'string', is_for_all: true, tracker_ids: Tracker.pluck(:id))
  end

  test 'the plugin settings page lists text custom fields and time zones' do
    field = text_field('Start time')
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_issue_ical'
    assert_response :success
    assert_select 'select#settings_start_time_field_id option[value=?]', field.id.to_s
    assert_select 'select#settings_end_time_field_id'
    assert_select 'select#settings_location_field_id'
    assert_select 'select#settings_client_field_id'
    assert_select 'select#settings_time_zone option[value=?]', 'Seoul'
  end

  test 'the issue form gets the time format script when time fields are set' do
    start_field = text_field('Start time')
    end_field = text_field('End time')
    settings = { 'start_time_field_id' => start_field.id.to_s, 'end_time_field_id' => end_field.id.to_s }
    log_user('jsmith', 'jsmith')
    with_settings(plugin_redmine_issue_ical: settings) do
      get '/projects/ecookbook/issues/new'
      assert_response :success
      assert_includes response.body, "input#issue_custom_field_values_#{start_field.id}, input#issue_custom_field_values_#{end_field.id}"
      assert_select "input#issue_custom_field_values_#{start_field.id}"
    end
  end

  test 'no time format script without time fields' do
    log_user('jsmith', 'jsmith')
    get '/projects/ecookbook/issues/new'
    assert_response :success
    assert_not_includes response.body, "placeholder = '09:30'"
  end
end
