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
    body = feed_body(key: User.find(2).atom_key).gsub("\r\n ", '')
    assert_includes body, 'URL:http://test.host/issues/4'
    assert_includes body, 'DESCRIPTION:Status: New\\nPriority: '
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
    assert_select '#issue-ical-modal-my a.issue-ical-settings-link'
  end

  test 'closed issues option is saved from my account' do
    log_user('jsmith', 'jsmith')
    put '/my/account', params: { user: { firstname: 'John' }, pref: { issue_ical_closed: 'hide' } }
    assert_redirected_to '/my/account'
    assert_equal 'hide', User.find(2).pref.issue_ical_closed
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

  test 'anonymous users see no feed links' do
    get '/projects/ecookbook/issues'
    assert_response :success
    assert_select 'ul.issue-ical-links', 0
  end
end
