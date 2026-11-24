# Changelog

## 0.5.0 (2026-11-25)

- New per-user option *My account → Preferences → Calendar: my issues → Include watched issues* (off by default). When on, the personal feed also lists issues you (or your groups) watch, so work shared with several people can be followed even though Redmine has a single assignee. Off by default because Redmine automatically makes authors and commenters watchers.

## 0.4.1 (2026-11-25)

- Shorter default calendar names in the user's language: *Issues* (Korean: 일감) for the personal feed and *Issues of <project>* for a project feed, instead of `<app title> - My issues`. Calendar apps such as Apple Calendar use this name when you subscribe.

## 0.4.0 (2026-11-25)

- The preference became *Calendar status display* with five choices: ✔ on closed (default), O closed / X open, status name on every issue, no marker, or hide closed issues. A choice saved in 0.3.0 carries over.
- The **Change** link in the subscribe dialog now closes the dialog and jumps to the setting when you are already on My account (before, it only changed the URL behind the open dialog).

## 0.3.0 (2026-11-25)

- Closed issues now stay in the calendar with a `✔ ` prefix instead of disappearing.
- New per-user preference *My account → Preferences → Closed issues in calendar*: keep them marked with ✔ (default) or leave them out. Existing subscriptions follow the preference without subscribing again.
- The subscribe dialog shows the current choice with a link to change it.

## 0.2.0 (2026-11-25)

- The *My account* button now matches the other buttons (icon + label) and opens a dialog instead of linking to the feed, so clicking no longer downloads an `.ics` file.
- The dialog shows the feed URL with a **Copy** button and one-click subscribe links for Apple Calendar / Outlook (`webcal://`) and Google Calendar.
- The issue list sidebar opens the same dialog for the personal and project feeds.

## 0.1.0 (2026-11-25)

- First release: personal and project iCalendar feeds of issue start and due dates, authenticated with the Atom access key.
