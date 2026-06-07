# Comprehensible Input Reading Log

A mobile-first, local-first reading tracker for language learners using
comprehensible input. Comprehensible Input Reading Log keeps separate language
shelves, tracks book progress and estimated word totals, and stores everything
in a local SQLite database.

The project favors manual entry, simple workflows, and device-local ownership
over accounts, cloud sync, social features, or external metadata dependencies.

## Features

- Create multiple reading logs for different languages
- Optionally set an estimated-word goal for each log
- Add and edit books with:
  - title and author
  - page count and estimated total words
  - difficulty
  - reading status
  - started and finished dates
  - notes
- Move books through `Want to read`, `In progress`, `Finished`, and `Abandoned`
- View dashboard totals for completed books, active books, completed words, and
  goal progress
- Open a detailed book view with lifecycle actions
- Delete individual books or entire reading logs with confirmation
- Keep the active reading log in the browser session
- Store application data outside the source repository

The interface is designed for phones first and uses Phoenix LiveView for
server-rendered interaction.

## Technology

- Elixir `~> 1.15`
- Phoenix 1.8
- Phoenix LiveView 1.1
- Ash 3
- AshSQLite and Ecto
- SQLite
- Tailwind CSS 4
- Bandit

## Getting Started

Prerequisites:

- Elixir and Erlang/OTP
- SQLite development support required by `exqlite`
- Standard build tools for compiling dependencies

Install dependencies, prepare the database, and build assets:

```sh
mix setup
```

Start the application:

```sh
mix phx.server
```

Then visit [http://localhost:4000](http://localhost:4000).

You can also run the server inside IEx:

```sh
iex -S mix phx.server
```

## Local Data

Development and production default to a `reading_log.db` SQLite database in the
current user's application-data directory:

| Platform | Default directory |
| --- | --- |
| Linux | `~/.local/share/reading_log/` |
| macOS | `~/Library/Application Support/reading_log/` |
| Windows | `%APPDATA%/reading_log/` |

The directory is created automatically before the repository connects.

Override the database location with `DATABASE_PATH`:

```sh
DATABASE_PATH=/absolute/path/to/reading_log.db mix phx.server
```

Test databases are isolated under `tmp/` and are ignored by Git. SQLite
database files and their journal files are also ignored.

### Existing Databases

Changing `DATABASE_PATH` or moving between the old repository-local setup and
the application-data directory does not copy existing data automatically. Move
or copy the SQLite database deliberately if you need to preserve an existing
library.

## Development

Run the full project check before committing:

```sh
mix precommit
```

This compiles with warnings treated as errors, removes unused dependency locks,
formats the code, prepares the test database, and runs the test suite.

Useful individual commands:

```sh
mix format
mix test
mix assets.build
```

Database migrations are managed through the normal Ecto/AshSQLite tasks:

```sh
mix ecto.migrate
```

## Architecture

The core domain is `CiBookTracker.Library`, with Ash resources for
`ReadingLog` and `Book`. Business operations are exposed through domain code
interfaces, including status transitions and deletion.

The primary UI consists of:

- a reading-log selector
- a dashboard scoped to the active reading log
- a shared add/edit book form
- a book detail page

The active reading log is stored in the browser session. There are no user
accounts or remote synchronization services.

## Metadata Lookup

Manual entry remains the primary workflow. The
`CiBookTracker.Library.BookMetadata` module is a placeholder boundary for
possible future integrations with:

- Open Library
- Hardcover
- Goodreads imports via Apify

No external metadata API calls are currently implemented.

## Configuration

Common environment variables:

| Variable | Purpose | Default |
| --- | --- | --- |
| `DATABASE_PATH` | Absolute SQLite database path | OS application-data path |
| `PORT` | HTTP port | `4000` in development |
| `POOL_SIZE` | Production database pool size | `10` |
| `PHX_HOST` | Production public host | `example.com` |
| `SECRET_KEY_BASE` | Production cookie/signing secret | Required in production |
| `PHX_SERVER` | Starts the endpoint in a release | Unset |
| `DNS_CLUSTER_QUERY` | Optional production DNS clustering query | Unset |

Generate a production secret with:

```sh
mix phx.gen.secret
```

## Deployment Scope

Comprehensible Input Reading Log currently has no authentication or multi-user
data isolation. It is intended as a personal, local-first application. Do not
expose it to an untrusted network without first adding an appropriate
authentication and authorization layer.

## Project Principles

- Mobile first
- Manual entry first
- Local SQLite storage
- No accounts
- No cloud sync
- No social features
- Simplicity over automation

See [`docs/prompts/00_philosophy.md`](docs/prompts/00_philosophy.md) for the
original project philosophy.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the
full text.
