Organize SQLite storage for a real local-first app.

Current issue:
- SQLite files are being created in the repository root.
- This is not appropriate for a real local app.

Goal:
Move application SQLite files into a user data directory outside the repo.

Preferred app data locations:
- Linux: ~/.local/share/reading_log/
- macOS: ~/Library/Application Support/reading_log/
- Windows: %APPDATA%/reading_log/

Requirements:
- Add a small module that resolves the app data directory based on the OS.
- Ensure the directory exists before opening the database.
- Store the default SQLite database at:
  <app_data_dir>/reading_log.db
- Keep test databases isolated under tmp/ or priv/data/test.
- Update AshSqlite/Ecto repo configuration to use the resolved database path.
- Remove or ignore old root-level SQLite files.
- Add gitignore entries for accidental local SQLite files:
  *.db
  *.db-*
  *.sqlite
  *.sqlite-*
- Do not store real app data in priv/.
- Do not add unrelated features.
- After changes, verify migrations and app startup still work.
