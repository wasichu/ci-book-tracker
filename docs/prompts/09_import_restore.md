Implement database import / restore.

Goal:
Allow users to restore CI Book Tracker from a previously exported SQLite database file.

User flow:
- Add a "Restore Database" action in Settings near "Export Database".
- User selects a SQLite database file.
- App validates the selected file.
- App shows a clear confirmation screen.
- If confirmed, replace the current database with the selected backup.
- Restart or instruct the user to restart if needed.

Important safety behavior:
- Never restore immediately after file selection.
- Show a destructive confirmation message:
  "This will replace your current reading logs, books, settings, and metadata provider configuration."
- Recommend exporting the current database first.
- Provide Cancel and Restore Database buttons.
- Cancel should do nothing.

Validation:
- Confirm the uploaded file is a readable SQLite database.
- Confirm expected tables exist.
- If possible, confirm schema/migration compatibility.
- If validation fails, show a friendly error and do not change the current database.

Backup-before-restore:
- Before replacing the current database, create an automatic safety backup of the current database.
- Store it in a local backups folder if the app already has one, otherwise use the app data directory.
- Use a timestamped filename like:
  ci_book_tracker_pre_restore_YYYY-MM-DD_HH-MM-SS.sqlite3

Restore behavior:
- Replace the current SQLite database file atomically if possible.
- If the app needs to restart after restore, show a message:
  "Restore complete. Please restart CI Book Tracker."
- Do not try to merge databases.
- Do not import partial data.
- This is full database replacement only.

Design:
- Mobile-first.
- Keep Restore visually separated from Export.
- Treat Restore as a dangerous/destructive action.
- Use clear language.
- Use Tailwind utilities only.

Scope:
- Do not implement CSV import.
- Do not implement JSON import.
- Do not implement cloud sync.
- Do not add accounts.
- Keep this focused on restoring the local SQLite database.
