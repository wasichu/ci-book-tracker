Implement a simple database export feature.

Goal:
Allow the user to download a backup of their local SQLite database.

Behavior:
- Add a Settings or Backup section accessible from the home/log selector or dashboard.
- Add a button labeled "Export Database".
- Clicking it should download the current SQLite database file.
- The downloaded filename should be clear, for example:
  ci_book_tracker_backup_YYYY-MM-DD.sqlite3

Requirements:
- Export the actual SQLite database file currently used by the app.
- Do not transform it into JSON for this task.
- Do not implement import/restore yet.
- Do not add cloud sync.
- Do not add accounts.
- Do not add external storage.

Safety:
- If the database file cannot be found, show a clear error flash.
- Make sure the export works with the configured app data path.
- Avoid hardcoding repo-root database paths.

Design:
- Mobile-first.
- Keep the UI simple.
- Use clear copy:
  "Download a copy of your local database for backup."

Scope:
- Only implement SQLite database export.
- Do not implement metadata lookup, covers, or unrelated features.
