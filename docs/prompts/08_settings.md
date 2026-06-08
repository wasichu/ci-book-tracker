Implement a Settings page for CI Book Tracker.

Goal:
Provide a simple, mobile-first settings page for application configuration, metadata providers, database information, and backup functionality.

Navigation:

* Add a Settings entry point from the home/log selector page and/or dashboard.
* Settings should be accessible regardless of which ReadingLog is active.

Sections:

1. Database

Display:

* Database file location
* Database file size
* Last modified timestamp if easily available

Actions:

* Export Database
* Show a short explanation:
  "All reading logs, books, and settings are stored locally in a SQLite database."

2. Metadata Providers

Open Library

Display:

* Enabled
* Informational text:
  "Open Library is available without an API key."

No configuration required.

Google Books

Display:

* Enabled toggle
* Optional API key input

Behavior:

* Provider should work without an API key.
* If an API key is provided, save it and use it for requests.
* Empty API key is valid.

Hardcover

Display:

* Enabled toggle
* API token input

Behavior:

* Provider should remain disabled unless a token is present.
* Save token locally when provided.
* Allow token updates and removal.

3. Application

Display:

* Application version if available
* Current environment if easily available

Future settings can be added here later.

Storage:

Create a simple settings storage mechanism.

Suggested approach:

* Store settings in SQLite.
* Use an Ash resource if appropriate.

Suggested fields:

* key
* value
* inserted_at
* updated_at

or

* provider
* enabled
* api_key_or_token

Use whichever approach best fits the current architecture.

Requirements:

* Settings must persist across restarts.
* Export Database should include all settings.
* API keys and tokens should be stored locally in SQLite.
* Do not require encryption for this task.
* Do not add cloud synchronization.
* Do not add accounts or authentication.

UX:

* Mobile-first.
* Single-column layout.
* Large touch targets.
* Labels above inputs.
* Clear section headings.
* Show success flash messages after saving settings.
* Use Tailwind utilities only.

Scope:

* Implement the Settings page.
* Implement persistence of metadata provider configuration.
* Integrate provider settings with existing metadata provider code where possible.
* Do not implement import/restore yet.
* Do not add unrelated settings.

Success Criteria:

A user can:

* Open Settings.
* View database information.
* Export the database.
* Configure Google Books API key.
* Configure Hardcover API token.
* Enable or disable providers.
* Restart the app and see settings persist.

