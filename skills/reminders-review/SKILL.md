---
name: reminders-review
description: Use when the user asks to review tasks, do a nightly review, morning glance, or manage Apple Reminders
---

# Reminders review

Task review workflows using `mcp__apple-reminders__reminders_tasks`.

## Nightly review

Don't ask questions. Just do it:

1. Read tasks: `dueWithin: "today"`, `dueWithin: "overdue"`, and `dueWithin: "no-date"` (three calls)
2. Filter out Shopping list and recurring system reminders (e.g. "Nightly review" itself)
3. Present remaining tasks in a table. For each, suggest: **Done**, **Defer**, or **Drop**
4. Act on user decisions:
   - Done: `action: "update"`, `completed: true`
   - Defer: `action: "update"`, new `dueDate`
   - Drop: `action: "delete"`
5. Plan tomorrow: max **3 tasks**. More causes paralysis.

## Morning glance

1. Read `dueWithin: "today"`
2. Present the list (skip Shopping, skip system reminders)
3. Ask: "Which one first?" — just pick one and go

## Defaults

- `targetList: "Reminders"` unless specified
- Always set `alarms: [{"relativeOffset": 0}]` on new reminders
- `dueDate` format: `YYYY-MM-DD HH:mm:ss`

## Known limitations

- Moving `targetList` may delete/recreate with new ID. Avoid.
- `addTags`/`removeTags` may not render in Reminders UI. Use lists instead.
- No section support within lists.
