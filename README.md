# Redmine Issue iCal

Subscribe to Redmine issues from any calendar app (Google Calendar, Apple Calendar, Outlook, Thunderbird, ...).
Every issue with a start date or a due date becomes an all-day event that spans from the start date to the due date.

[한국어 안내는 아래에 있습니다.](#한국어)

## Features

- **My issues** feed: issues assigned to you or to one of your groups, across all projects — optionally also the issues you watch.
- **Project** feed: issues of one project (subprojects follow the *Display subprojects issues on main projects by default* setting).
- **Per tracker**: either feed can be limited to one tracker (Bug, Feature, ...), so each tracker can be its own calendar.
- Uses Redmine permissions: a feed never shows an issue the user cannot see in Redmine.
- Authenticates with the user's existing **Atom access key**, so no new credentials are needed and the key can be reset at any time.
- A **Calendar subscription** button on the *My account* page and links in the issue list sidebar open a dialog with a **Tracker** picker, the feed URL, a **Copy** button, and one-click subscribe links for Apple Calendar / Outlook (`webcal://`) and Google Calendar.
- No extra gems and no database migrations.

## Requirements

- Redmine 7.0 or later (tested with Redmine 7.0.3 on Ruby 4.0 and on Ruby 3.3, Rails 8.1)

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/StopDragon/redmine_issue_ical.git
# restart Redmine
```

No migration is needed. To uninstall, delete the `plugins/redmine_issue_ical` directory and restart Redmine.

## Usage

1. Open *My account* and click **Calendar subscription**, or click **My issues** / **Issues of …** under *Calendar subscription* in the issue list sidebar.
2. In the dialog, optionally pick a tracker in the *Tracker* list (see below).
3. Then either
   - click **Open in Apple Calendar / Outlook** or **Add to Google Calendar**, or
   - click **Copy** and add the URL to your calendar app as a calendar *from URL* / *subscription*.

To get one calendar per tracker, pick a tracker in the dialog's *Tracker* list before subscribing, and repeat for each tracker you want. The list shows the trackers whose issues you can see (for a project feed, the trackers of that project). Each becomes a separate calendar (named e.g. *Issues - Bug*) that you can color or hide on its own in the calendar app. *All trackers* keeps everything in one calendar; if you switch to per-tracker calendars, remove the old all-trackers subscription or every issue shows twice.

Do not download the `.ics` file and import it: an imported file is a one-time copy and never updates. Subscribe to the URL instead.

Feed URLs:

| Feed | URL |
|---|---|
| My issues | `https://redmine.example.org/issue_ical/my.ics?key=ATOM_KEY` |
| Project | `https://redmine.example.org/projects/PROJECT/issue_ical.ics?key=ATOM_KEY` |
| One tracker only | add `&tracker_id=TRACKER_ID` to either URL |

### How issues map to events

| Issue | Event |
|---|---|
| Start date and due date | All-day event from the start date through the due date |
| Due date only | All-day event on the due date |
| Start date only | All-day event on the start date |
| No dates | Not included |
| Closed | Kept with a marker, or left out (per-user preference, see below) |

- Title: `[Project] Tracker #123: Subject`, or `Client-Subject(#123)` when a project custom field is picked as the client (see below)
- Description: the issue's own description as plain text, without Textile / Markdown markup (first 1000 characters), a blank line, then status, priority, assignee and % done (the issue link is sent as the event URL)
- Events are marked as *free* (`TRANSP:TRANSPARENT`), so they do not block your availability, except timed events (see below) of a priority above the default one (in a stock Redmine: High, Urgent, Immediate), which are marked *busy* (`TRANSP:OPAQUE`). All-day events always stay free, so a long issue does not make you look busy for weeks.
- At most 2,000 issues per feed.

Redmine stores start and due dates without a time, so events are all-day unless you set up time fields (below).

### Start and end times, location, client (optional)

Redmine has no time or location field, so they are kept in issue custom fields:

1. *Administration → Custom fields → New custom field → Issues*, format **Text**, one named e.g. *Start time* and one *End time*. A regular expression such as `^([01]\d|2[0-3]):?[0-5]\d$` lets only times like `09:30` or `0930` through.
2. For a location, another **Text** custom field, e.g. *Location*.
3. *Administration → Plugins → Redmine Issue iCal → Configure*: pick the fields, and optionally the time zone the times are written in.

Then:

| Start time | End time | Event |
|---|---|---|
| filled | filled | from the start date at the start time to the due date at the end time |
| filled | empty | from the start date at the start time to one hour after the start time on the due date (a single-day issue: one hour) |
| empty | any | all-day, as before |

- Once both fields are picked, an issue cannot be saved with only one of the two times: Redmine asks for the other one. Older issues that already have a single time can still be edited for other reasons until someone changes a time; the check is skipped when a field is not enabled for the issue or the user may not edit it.
- `09:30:00` (seconds dropped) and a full-width colon `09：30` are accepted too. An end at or before the start becomes one hour from the start; a value that is not a time (e.g. `soon`) keeps the issue all-day.
- Times are read in the user's time zone (*My account → Preferences*), else the time zone picked in the plugin settings, else the server's. They are sent in UTC, so every calendar app shows them in its own time zone.
- The location field is sent as the event location (`LOCATION`). Apple Calendar can look an address up on the map; a meeting link works too.
- **Alarms**: pick an issue custom field as the *Alarm field*, ideally a **List** with *Multiple values* and values such as `정시`, `1분 전`, `5분 전`, `10분 전`, `15분 전`, `30분 전`, `1시간 전`, `2시간 전`, `1일 전`, `2일 전`, `1주 전`, `끝나기 10분 전` (English works too: `At time of event`, `15 minutes before`, `1 day before`, `10 minutes before end`). Any "number + 분/시간/일/주 전" is understood. Each picked value becomes an alarm (`VALARM`). `없음` (or `None`) on its own sends a "no alarm" (`ACTION:NONE`, RFC 9074) so that calendar apps that understand it, such as Apple Calendar, do not add their default alarm; when the field is empty, nothing is sent and the app's default alarm applies. Other values are ignored. All-day events have no time, so their alarms count from 09:00: `30분 전` rings at 08:30 on the first day, `1일 전` at 09:00 the day before. Apple Calendar rings them (unless *Remove: Alerts* is ticked for the subscription); Google Calendar ignores alarms in subscribed calendars and uses its own defaults.
- **Client in the title**: pick a project custom field (format Text or List) as the *Client field* in the same settings. Titles then read `Client-Subject(#123)`, or `Subject(#123)` when the project has no client (or the user may not see the field). The status marker still comes first.
- As on the issue page, a field value is not used when the field is not enabled for the issue's project and tracker, or the user may not see it (custom field visibility by role).
- On the issue form, `930`, `0930` or `9` turns into `09:30` / `09:00` when you leave the field or save, so you do not need to type the colon.

### Status display (per-user preference)

Each user chooses under *My account → Preferences → Calendar status display* how issue status shows up in event titles:

| Option | Closed issue | Open issue |
|---|---|---|
| **✔ on closed** (default) | `✔ [Project] Bug #12: …` | `[Project] Bug #13: …` |
| **O closed / X open** | `O [Project] …` | `X [Project] …` |
| **Status name** | `[Closed] [Project] …` | `[In Progress] [Project] …` |
| **No marker** | `[Project] …` | `[Project] …` |
| **Hide closed issues** | not in the calendar | `[Project] …` |

The preference is read every time the feed is fetched, so existing subscriptions follow a change without subscribing again (at the next refresh). It applies to both the personal and the project feeds of that user. "Closed" means a status marked *Issue closed* in Redmine's status settings. The **Change** link in the subscribe dialog jumps to this setting.

### Watched issues (per-user preference)

Redmine has a single assignee per issue. To follow work shared with several people, add them as watchers and turn on *My account → Preferences → Calendar: my issues → Include watched issues*. The personal feed then also lists issues you (or your groups) watch.

It is off by default because Redmine automatically makes the author and commenters watchers (*Auto watch* in My account), so turning it on also brings in issues you created and handed over.

### Calendar name

The feed suggests a calendar name in the user's language: **Issues** (Korean: **일감**) for the personal feed and **Issues of <project>** (Korean: **<project> 일감**) for a project feed. Apple Calendar and most other apps use it as the default when you subscribe, and you can rename the calendar in the app.

### Refresh interval

The calendar app decides how often it reloads the feed. The feed suggests one hour, but Google Calendar may take up to about a day and Outlook several hours. Apple Calendar lets you choose the interval.

For Google Calendar and Outlook.com, the feed URL must be reachable from the internet, because their servers fetch it.

## Security

The feed URL contains your **Atom access key**. This is the same key Redmine uses for all of your Atom feeds, so anyone who has the URL can read:

- the issues in this calendar feed, and
- **every Redmine Atom feed you can access** (issues, activity, news, ... — limited to what you can see).

The key cannot be used to log in to the web interface or to change anything.

Treat the URL like a password. If it leaks, reset the key under *My account → Atom access key → Reset*. Every feed URL with the old key stops working, including Redmine's own Atom feeds, so subscribe again with the new link.

## Development

Run the tests from the Redmine root:

```bash
bin/rails redmine:plugins:test NAME=redmine_issue_ical RAILS_ENV=test
```

## Credits

The calendar icon is from [Tabler Icons](https://tabler.io/icons) (MIT License), the icon set Redmine itself uses.

## License

GNU General Public License v2.0 or later. See [LICENSE](LICENSE).

---

## 한국어

Redmine 일감의 시작일·종료일을 캘린더 앱(Google 캘린더, Apple 캘린더, Outlook 등)에서 구독할 수 있게 해 주는 플러그인입니다. 시작일이나 종료일이 있는 일감이 시작일부터 종료일까지의 종일 일정으로 들어갑니다.

- **내 일감**: 나 또는 내가 속한 그룹에 배정된 일감(전체 프로젝트)
- **관찰 중인 일감**: **내 계정 → 설정 → 캘린더 내 일감 → 관찰 중인 일감 포함**을 켜면 내가 관찰자인 일감도 내 일감 캘린더에 들어갑니다(기본 꺼짐). Redmine은 담당자가 한 명이라, 함께 하는 사람은 관찰자로 넣으면 됩니다. 일감을 만든 사람과 댓글 단 사람은 자동으로 관찰자가 되므로, 켜면 내가 만든 일감도 함께 들어옵니다.
- **프로젝트 일감**: 해당 프로젝트의 일감
- **유형별 캘린더**: 구독 창의 **유형** 목록에서 버그·기능 같은 유형을 고르면 그 유형만 담긴 주소가 됩니다. 유형마다 따로 구독하면 캘린더 앱에서 유형별로 색을 다르게 하거나 켜고 끌 수 있습니다(캘린더 이름 예: 「일감 - 버그」). 「모든 유형」은 지금처럼 하나로 받습니다. 유형별로 바꿔 구독하면 기존 「모든 유형」 구독은 지워야 일정이 두 번 나오지 않습니다.
- **상태 표시**: 사용자마다 **내 계정 → 설정 → 캘린더 상태 표시**에서 고릅니다. 「완료에 ✔」(기본) / 「완료 O / 미완료 X」 / 「상태 이름 (예: [진행])」 / 「표시 없음」 / 「완료 일감 빼기」 중 하나이고, 다음 새로고침 때 반영됩니다. 이미 구독한 주소를 바꿀 필요는 없습니다. 구독 창의 **설정 바꾸기** 링크로 바로 갈 수 있습니다.
- Redmine 권한을 그대로 따르므로 내가 볼 수 없는 일감은 나오지 않습니다.
- 인증은 기존 **Atom 접근키**를 씁니다. 따로 비밀번호를 만들지 않아도 됩니다.

### 사용법

1. **내 계정** 오른쪽 위 **캘린더 구독** 버튼, 또는 일감 목록 사이드바의 **캘린더 구독 → 내 일감 / ○○ 일감**을 누릅니다.
2. 뜨는 창에서, 유형별로 받으려면 **유형** 목록에서 유형을 고릅니다(볼 수 있는 유형만 나오고, 프로젝트 일감 창에는 그 프로젝트의 유형만 나옵니다).
3. 그다음
   - **Apple 캘린더·Outlook으로 열기** 또는 **Google 캘린더에 추가**를 누르거나,
   - **복사**를 눌러 주소를 캘린더 앱에 **URL로 구독**(Google 캘린더: 다른 캘린더 → URL로 추가)합니다.

`.ics` 파일을 내려받아 가져오기(import)하면 그때 일정만 한 번 복사되고 갱신되지 않습니다. 반드시 주소로 구독하세요.

### 알아 둘 점

- Redmine 일감 날짜에는 시간이 없어 항상 종일 일정으로 표시됩니다.
- 다시 읽는 주기는 캘린더 앱이 정합니다(Google은 최대 하루 정도 걸릴 수 있음).
- Google 캘린더나 Outlook.com으로 구독하려면 Redmine 주소가 인터넷에서 열려 있어야 합니다.
- 링크에 **Atom 접근키**가 들어 있습니다. 이 키는 Redmine의 모든 Atom 피드에 쓰이는 키라서, 링크를 가진 사람은 이 캘린더뿐 아니라 **내가 볼 수 있는 모든 Atom 피드**(일감, 활동, 뉴스 등)를 읽을 수 있습니다. 웹 로그인이나 수정은 할 수 없습니다.
- 링크는 비밀번호처럼 다루세요. 유출되면 **내 계정 → Atom 접근키 → 초기화**를 누르고 새 링크로 다시 구독하세요. 이전 키가 들어간 피드 주소는 모두 멈춥니다.
