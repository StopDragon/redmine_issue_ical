# Changelog

## 0.7.0 (2026-11-27)

- Start and end times: pick two issue custom fields (format Text, e.g. `09:30`) under *Administration → Plugins → Configure*. Issues with a start time become timed events from the start date at the start time to the due date at the end time (when the end time is empty, it ends one hour after the start time on the due date); others stay all-day. Times are read in the user's time zone, else the one set for the plugin, else the server's, and sent in UTC. Fields hidden from the user by role are not used.
- Location: a third custom field picked in the same settings is sent as the event location.
- Issues of a priority above the default one (High, Urgent, Immediate in a stock Redmine) show as busy in the calendar; the others stay free.
- On the issue form the time fields get the colon added for you: `930` or `0930` becomes `09:30` when you leave the field or save.
- The event description now starts with the issue's own description as plain text, without Textile / Markdown markup (cut off after 1000 characters), followed by a blank line and the status, priority, assignee and % done lines.
- The event description no longer repeats the issue link; it is sent once as the event URL, which calendar apps show as a link.

## 0.6.0 (2026-11-26)

- Feeds per tracker: the subscribe dialog has a *Tracker* picker (*All trackers* or one tracker). Picking a tracker changes the URL and the subscribe links to a calendar of only that tracker, so each tracker can be subscribed to separately and colored or toggled in the calendar app. Works for both the personal and the project feeds (`tracker_id=N` in the URL); the calendar is named e.g. *Issues - Bug*.
- The picker lists only the trackers whose issues you can see; a project feed lists the trackers of that project (and of its subprojects when they are shown). An unknown or hidden tracker in the URL returns 404.

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
