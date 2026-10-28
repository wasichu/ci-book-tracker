# CI Book Tracker

Local-first reading tracker built with Phoenix 1.8, LiveView, Ash, and SQLite.
It is a personal application with multiple reading logs, not an authenticated
multi-user service. Preserve offline manual entry and user-owned local data.

## Commands and verification

Use the toolchain pinned in `.tool-versions`.

- Setup: `mix setup`
- Development server: `mix phx.server` (`PORT=4100 mix phx.server` for another port)
- Focused tests: `mix test test/path/to_test.exs` (append `:LINE` for one test)
- Required final check after changes: `mix precommit`; fix failures before finishing.
- Build changed JS/CSS assets: `mix assets.build`
- CI checks: `mix ci` (checks formatting, compilation, tests, and assets)

Run focused checks while iterating and the required final check when done. Repeat
checks when changes or failures justify it. For UI changes, inspect the affected
screen in a browser when available. Report checks actually run and any gaps.

## Repository map

- `lib/ci_book_tracker/`: Ash domains/resources, metadata, local storage, backups.
- `lib/ci_book_tracker_web/`: LiveViews, components, controllers, workspace/session UI.
- `assets/css/app.css`, `assets/js/`: Workbench styling and browser hooks.
- `test/`: domain, LiveView, controller, backup, and restore coverage.
- [Architecture](docs/architecture.md): domain boundaries and workflow explanations.
- [Distribution](docs/distribution.md): native builds, release checks, and Homebrew.
- [README](README.md): current user workflows, configuration, and storage paths.

## Engineering constraints

- Use the existing `Req` HTTP client, not HTTPoison, Tesla, or `:httpc`.
- Consult relevant Ash documentation before using unfamiliar Ash features. Prefer
  domain code interfaces over direct `Ash.*` calls in LiveViews/controllers. Put
  domain business logic in resource actions and reusable change/validation modules.
- Prefer atomic Ash updates. Add `require_atomic? false` only when hooks or logic
  genuinely require reading/modifying the loaded record.
- Follow existing boundaries and patterns; do not add abstractions or dependencies
  for a small change without a concrete benefit.
- Use existing test fixtures and SQL sandbox support. Keep tests independent of live
  metadata services and personal data; cover meaningful behavior changes.

## UI constraints

- Begin LiveView templates with `<Layouts.app flash={@flash} workspace={@workspace}>`.
  Workspace views belong in the router's `:workspace` live session and mount hook.
- Use the imported `<.icon>` and `<.input>` components. Call `<.flash_group>` only
  from `layouts.ex`; do not reintroduce routine success popups.
- Preserve the approved Slate and Iris Workbench, compact panes, and dashboard-style
  outlined action buttons. Reuse existing styles before inventing new treatments.
- For UI changes, read [Phoenix UI conventions](docs/agent-reference/phoenix-ui.md).

## Local data and release constraints

- Personal data is outside the repository. Development can use the same default
  database as a packaged installation; use isolated sample data for experiments,
  screenshots, restore tests, and release smoke tests.
- `DATABASE_PATH` overrides only the database. Packaged installations can use
  `CI_BOOK_TRACKER_DATA_DIR` to select the database, covers, and secret directory.
  These settings do not copy existing files.
- Preserve ZIP backups with local covers, legacy SQLite restore compatibility,
  migration checks, and automatic safety backups before replacement. Export,
  upload, and expanded-backup limits must remain consistent.
- Packaged releases generate/persist their session secret and run migrations on
  startup. Follow `docs/distribution.md` for packaging, platform checks, and releases.

## Context and reference guidance

- Keep this file concise: project commands, constraints, gotchas, and reference links.
  Do not paste dependency manuals or task transcripts into it.
- Read only the references and code needed for the current task. Search symbols
  before broad file reads; keep large logs on disk and report useful excerpts.
- For long work, preserve a short handoff with objective, decisions, changed files,
  verified checks, unresolved issues, and next step. Verify it against current code.
- Detailed dependency guidance lives in
  [framework usage rules](docs/agent-reference/framework-rules.md). Read the relevant
  topic when changing Ash actions/queries/relationships, Phoenix/HEEx/LiveView,
  Ecto, Elixir, or OTP behavior; unrelated documentation edits do not need it.
- Local API docs: `mix usage_rules.docs Ash.Query` or
  `mix usage_rules.docs Ash.Query.for_read/4`.
- Search docs: `mix usage_rules.search_docs "query preparations" -p ash`.
- Regenerate dependency guidance with `mix usage_rules.sync`. Its output belongs in
  `docs/agent-reference/framework-rules.md`, not this startup file.
