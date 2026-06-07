Implement Reading Log selection and lightweight session behavior.

Current issue:
- After creating a ReadingLog, the app goes directly into that log.
- There is no way to return to a home screen that lists existing reading logs.
- There is no way to choose a different log or create another log from the home screen.
- There is no logout/switch-log behavior.

Goal:
Add a simple local-first “home” flow for choosing reading logs.

Behavior:

1. Home page
- The root page should act as a reading log selector.
- It should list existing ReadingLogs.
- Each log card should show:
  - name
  - language_code
  - word_goal if present
  - basic stats if easy to compute, otherwise omit for now
- Each log card should have an “Open” button.
- The page should also have a prominent “Create New Reading Log” button.

2. Creating a log
- Creating a ReadingLog should automatically open that log after save.
- The create form should include:
  - name
  - language_code, default "es"
  - word_goal, optional
  - checkbox: “Automatically open this log next time”
- If that checkbox is checked, persist that preference locally.

3. Opening a log
- Opening a ReadingLog should mark it as the currently active log for the current browser/session.
- After opening, navigate to that log’s dashboard.

4. Auto-open behavior
- If the user has selected “Automatically open this log next time,” visiting the root page should automatically open that log.
- There should still be a way to return to the home/log selector page.

5. Logout / switch log
- On the reading log dashboard, add a simple “Switch Log” or “Log Out” action.
- Clicking it should clear the current active log from the session.
- It should return the user to the home/log selector page.
- Do not delete any ReadingLog.
- Do not delete any books.

6. Persistence
- Use Phoenix session or another simple local-first mechanism for the current active log.
- If needed, store the auto-open preference in a small local setting, cookie, or simple persisted app setting.
- Keep this minimal. Do not add full authentication.
- Do not add users, passwords, accounts, or cloud sync.

7. Routing expectation
- Root path should show the log selector unless auto-open is enabled.
- The dashboard should be scoped to a selected ReadingLog.
- Book creation and listing should use the active ReadingLog only.

Design:
- Mobile first.
- Single-column layout.
- Large touch targets.
- No tables.
- Use Tailwind utilities only.
- Keep the interface simple and clear.

Do not implement metadata lookup, book detail pages, covers, or unrelated features.
