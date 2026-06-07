Add ReadingLog deletion from the home/log selector page.

Goal:
Allow the user to delete a reading log and all books associated with it.

Behavior:
- On the home/log selector page, each ReadingLog card should include a secondary "Delete" action.
- Deleting a ReadingLog should also delete all associated Books.
- Before deletion, show a clear confirmation prompt.
- The confirmation should say the log name and explain that books in that log will also be deleted.
- Do not delete immediately from a single accidental tap.

Confirmation options:
- Cancel
- Delete Reading Log

If the deleted log is currently active:
- clear the active log from the session.
- return to the home/log selector page.

If the deleted log was selected for auto-open:
- clear the auto-open preference.

Design:
- Mobile-first.
- Delete should be visually secondary/destructive.
- Avoid placing Delete as the most prominent button.
- Use Tailwind utilities only.

Scope:
- Do not add archive/restore yet.
- Do not add metadata lookup.
- Do not add unrelated features.
