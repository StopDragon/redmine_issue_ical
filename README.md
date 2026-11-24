# Redmine Issue iCal

Subscribe to Redmine issues from any calendar app (Google Calendar, Apple Calendar, Outlook, Thunderbird, ...).
Every issue with a start date or a due date becomes an all-day event that spans from the start date to the due date.

[한국어 안내는 아래에 있습니다.](#한국어)

## Features

- **My issues** feed: issues assigned to you or to one of your groups, across all projects.
- **Project** feed: issues of one project (subprojects follow the *Display subprojects issues on main projects by default* setting).
- Uses Redmine permissions: a feed never shows an issue the user cannot see in Redmine.
- Authenticates with the user's existing **Atom access key**, so no new credentials are needed and the key can be reset at any time.
- A **Calendar subscription** button on the *My account* page and links in the issue list sidebar open a dialog with the feed URL, a **Copy** button, and one-click subscribe links for Apple Calendar / Outlook (`webcal://`) and Google Calendar.
- No extra gems and no database migrations.

## Requirements

- Redmine 7.0 or later (tested with Redmine 7.0.3, Ruby 4.0, Rails 8.1)

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/StopDragon/redmine_issue_ical.git
# restart Redmine
```

No migration is needed. To uninstall, delete the `plugins/redmine_issue_ical` directory and restart Redmine.

## Usage

1. Open *My account* and click **Calendar subscription**, or click **My issues** / **Issues of …** under *Calendar subscription* in the issue list sidebar.
2. In the dialog, either
   - click **Open in Apple Calendar / Outlook** or **Add to Google Calendar**, or
   - click **Copy** and add the URL to your calendar app as a calendar *from URL* / *subscription*.

Do not download the `.ics` file and import it: an imported file is a one-time copy and never updates. Subscribe to the URL instead.

Feed URLs:

| Feed | URL |
|---|---|
| My issues | `https://redmine.example.org/issue_ical/my.ics?key=ATOM_KEY` |
| Project | `https://redmine.example.org/projects/PROJECT/issue_ical.ics?key=ATOM_KEY` |

### How issues map to events

| Issue | Event |
|---|---|
| Start date and due date | All-day event from the start date through the due date |
| Due date only | All-day event on the due date |
| Start date only | All-day event on the start date |
| No dates | Not included |
| Closed | Kept with a marker, or left out (per-user preference, see below) |

- Title: `[Project] Tracker #123: Subject`
- Description: status, priority, assignee, % done and the issue link
- Events are marked as *free* (`TRANSP:TRANSPARENT`), so they do not block your availability.
- At most 2,000 issues per feed.

Redmine stores start and due dates without a time, so events are always all-day.

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
- **프로젝트 일감**: 해당 프로젝트의 일감
- **상태 표시**: 사용자마다 **내 계정 → 설정 → 캘린더 상태 표시**에서 고릅니다. 「완료에 ✔」(기본) / 「완료 O / 미완료 X」 / 「상태 이름 (예: [진행])」 / 「표시 없음」 / 「완료 일감 빼기」 중 하나이고, 다음 새로고침 때 반영됩니다. 이미 구독한 주소를 바꿀 필요는 없습니다. 구독 창의 **설정 바꾸기** 링크로 바로 갈 수 있습니다.
- Redmine 권한을 그대로 따르므로 내가 볼 수 없는 일감은 나오지 않습니다.
- 인증은 기존 **Atom 접근키**를 씁니다. 따로 비밀번호를 만들지 않아도 됩니다.

### 사용법

1. **내 계정** 오른쪽 위 **캘린더 구독** 버튼, 또는 일감 목록 사이드바의 **캘린더 구독 → 내 일감 / ○○ 일감**을 누릅니다.
2. 뜨는 창에서
   - **Apple 캘린더·Outlook으로 열기** 또는 **Google 캘린더에 추가**를 누르거나,
   - **복사**를 눌러 주소를 캘린더 앱에 **URL로 구독**(Google 캘린더: 다른 캘린더 → URL로 추가)합니다.

`.ics` 파일을 내려받아 가져오기(import)하면 그때 일정만 한 번 복사되고 갱신되지 않습니다. 반드시 주소로 구독하세요.

### 알아 둘 점

- Redmine 일감 날짜에는 시간이 없어 항상 종일 일정으로 표시됩니다.
- 다시 읽는 주기는 캘린더 앱이 정합니다(Google은 최대 하루 정도 걸릴 수 있음).
- Google 캘린더나 Outlook.com으로 구독하려면 Redmine 주소가 인터넷에서 열려 있어야 합니다.
- 링크에 **Atom 접근키**가 들어 있습니다. 이 키는 Redmine의 모든 Atom 피드에 쓰이는 키라서, 링크를 가진 사람은 이 캘린더뿐 아니라 **내가 볼 수 있는 모든 Atom 피드**(일감, 활동, 뉴스 등)를 읽을 수 있습니다. 웹 로그인이나 수정은 할 수 없습니다.
- 링크는 비밀번호처럼 다루세요. 유출되면 **내 계정 → Atom 접근키 → 초기화**를 누르고 새 링크로 다시 구독하세요. 이전 키가 들어간 피드 주소는 모두 멈춥니다.
