# Architecture and Design

CI Book Tracker is a local-first Phoenix LiveView application backed by Ash and
SQLite. It is organized around a small domain model, with external metadata and
database backup services kept behind focused boundaries.

The application has four primary layers:

1. Ash domain and resources
2. Local SQLite persistence
3. Phoenix LiveView web interface
4. Optional metadata provider integrations

## Domain Layer

`CiBookTracker.Library` is the main Ash domain. Its principal resources are:

- `CiBookTracker.Library.ReadingLog`
- `CiBookTracker.Library.Book`

A reading log represents one language-specific collection and can have a word
goal. Books belong to one reading log and contain their reading status, dates,
page count, estimated words, difficulty, notes, and optional cover metadata.
Remote source metadata is retained when applicable, while `cover_path` points
to the locally stored image used by the application.

Business operations are defined as Ash actions and exposed through domain code
interfaces. These operations include:

- Creating, editing, and deleting reading logs
- Creating, editing, and deleting books
- Attaching and removing locally stored book covers
- Starting, finishing, abandoning, and reopening books

The web layer calls these interfaces instead of directly updating records.
This keeps status transitions, date handling, validation, and persistence in
the domain rather than scattering those rules across LiveViews.

## Book Status Workflow

Books have four statuses:

```text
Want to Read -> In Progress -> Finished
       |             |
       +-------------+-----> Abandoned

Finished or Abandoned -> Reopen -> In Progress
```

The Ash actions are the source of truth for these transitions and their date
changes. For example, starting a book sets its start date when needed, while
finishing it completes the relevant reading dates.

LiveViews only request a transition, display the updated book, and show a
resulting flash message.

## Persistence and Local Data

AshSQLite and Ecto store application data in a local SQLite database. The
database includes:

- Reading logs
- Books
- Metadata provider settings
- Locally configured provider credentials

By default, the database is stored in the operating system's application-data
directory. `CiBookTracker.AppData` resolves the appropriate path for Linux,
macOS, or Windows. Local cover images are stored in a sibling `covers/`
directory. `DATABASE_PATH` can override the database location.

The application does not require user accounts, a remote database, or cloud
synchronization.

## Web Layer

Phoenix LiveView provides the interactive user interface. Major screens
include:

- Reading-log selection
- Reading-log creation and editing
- Reading dashboard
- Shared add/edit book form
- Book detail page
- CSV book import
- Settings
- Database export and restore

The active reading log is stored in the browser session.
`CiBookTrackerWeb.ReadingLogSession` owns session-key precedence and resolves
the selected log for LiveViews. Routes that operate on books also verify that
the requested book belongs to that active log.

LiveViews own temporary interface state such as:

- Search terms and status filters
- Forms and validation feedback
- Metadata search results
- Delete confirmations
- Upload previews
- Word-estimator samples

Persisted state and business rules remain in Ash resources and supporting
domain modules.

## Metadata Architecture

`CiBookTracker.Library.BookMetadata` is the boundary for optional book
metadata lookup. It supports:

- Open Library
- Google Books
- Hardcover
- Searching all enabled providers

Each provider uses `Req` to call its API and parses its provider-specific
response. Results are converted into a common
`CiBookTracker.Library.BookMetadata.Result` structure:

```elixir
%CiBookTracker.Library.BookMetadata.Result{
  provider: :open_library,
  provider_id: "...",
  title: "...",
  author: "...",
  page_count: 237,
  isbn_10: "...",
  isbn_13: "...",
  language_code: "es",
  publish_year: 2024,
  cover_url: "https://..."
}
```

The form therefore does not need to understand Open Library documents, Google
Books volumes, or Hardcover GraphQL results. It only handles the shared result
type.

Metadata lookup remains optional. Selecting a result prefills the form, but the
book is not persisted until the user saves it. Manual entry works without any
provider or internet connection.

## Metadata Normalization

Provider APIs represent equivalent values in different ways. Shared cleanup
lives in `CiBookTracker.Library.BookMetadata.Normalization`, while parsing
provider-specific response shapes remains inside each provider module.

Normalization handles:

- ISBN cleanup and validation
- Language-code normalization
- Positive-integer validation and parsing
- Converting insecure cover URLs to HTTPS
- Converting empty optional strings to `nil`

Examples:

```text
978-0-307-47472-8 -> 9780307474728
spa               -> es
FRA               -> fr
pt-BR             -> pt
http://...         -> https://...
""                 -> nil
```

Open Library and Google Books provide numeric page counts as integers.
Hardcover may provide them as strings, so the shared normalizer exposes a
separate parser for that provider behavior. This avoids silently broadening
the accepted input shapes of other integrations.

## Supporting Services

Several focused modules handle workflows outside the two main resources:

- `CiBookTracker.Library.BookCsvImport` validates, previews, and imports CSV
  rows.
- `CiBookTracker.Library.WordEstimator` counts a representative text sample
  and extrapolates an estimated total.
- `CiBookTracker.Library.BookCover` validates and stores uploaded or downloaded
  images, serves path information, and backfills older remote-only covers.
- `CiBookTracker.Settings.MetadataProviders` manages provider availability and
  credentials.
- `CiBookTracker.BackupArchive` owns the portable ZIP layout, archive limits,
  packing, safe-path validation, and extraction.
- `CiBookTracker.DatabaseBackup` snapshots SQLite and delegates portable
  archive creation to `BackupArchive`.
- `CiBookTracker.DatabaseValidation` checks SQLite integrity, required tables,
  and migration compatibility.
- `CiBookTracker.DatabaseRestore` stages ZIP or legacy SQLite backups, creates
  a complete safety archive, and safely replaces the active data.
- `CiBookTrackerWeb.BookLive.FormParams` owns deterministic book-form
  normalization and metadata transformations.
- `CiBookTrackerWeb.BookLive.FormComponents` contains the stateless metadata,
  cover, and book-field presentation used by the add/edit LiveView.
- `CiBookTrackerWeb.ReadingLogFormat` formats language names and reading goals.
- `CiBookTrackerWeb.BookFormat` consistently formats book statuses, numbers,
  word totals, dates, and status messages.

## Main Application Flows

### Adding or Editing a Book

1. The LiveView loads the active reading log and optional existing book.
2. The user enters values manually or searches for metadata.
3. A selected metadata result prefills the shared form.
4. The optional word estimator can calculate an estimated total from a sample.
5. An uploaded image or cover URL is stored in the application-data directory.
6. Saving selects one explicit Ash action for an unchanged, replaced, or
   removed cover.
7. Ash validates and persists ordinary edits and the cover change as one
   database operation.

Cover attachment and cover-aware edits are dedicated Ash actions. Successful
replacement removes the superseded file, failed persistence removes the newly
written file without committing other edits, and book or reading-log deletion
removes associated local files.

### Updating Book Status

1. The dashboard or book detail page submits a transition name.
2. The LiveView calls the corresponding Library code interface.
3. The Ash action applies status and date rules.
4. The LiveView reloads or assigns the updated book and displays a message.

### Importing Books

1. The user uploads a CSV file.
2. `BookCsvImport` parses headers and validates each row.
3. The LiveView displays a preview with row-level errors.
4. Confirming the import creates valid books through the Library domain.

### Exporting and Restoring Data

1. `DatabaseBackup` snapshots SQLite and asks `BackupArchive` to create a ZIP
   containing `reading_log.db` and `covers/`.
2. `BackupArchive` safely stages the fixed ZIP layout; legacy SQLite files are
   staged directly.
3. `DatabaseValidation` checks integrity and derives migration compatibility
   from the repository migration files.
4. The current database and covers are archived before replacement.
5. Database replacement is rolled back if cover replacement fails.
6. The repository connection is safely restarted around the file swap.

## Earlier Refactor Pass

An earlier packaging refactor focused on duplication rather than architecture
changes. It introduced two small shared modules:

- `CiBookTrackerWeb.BookFormat`
- `CiBookTracker.Library.BookMetadata.Normalization`

The refactor removed repeated formatting helpers from the dashboard, book form,
book detail page, and CSV import page. It also removed repeated ISBN, language,
integer, URL, and blank-value normalization from the three metadata providers.

Status-action button definitions remain local to the dashboard and book detail
page because their grid classes and responsive layouts intentionally differ.
Keeping those definitions separate is clearer than forcing a shared abstraction
that would still require page-specific presentation options.

That pass did not change the database schema, domain actions, routes, or visible
application behavior. Later cover-storage and portable-backup work did extend
the schema and domain actions described above.

## Design Principles

- Keep Ash actions and domain interfaces as the source of truth.
- Keep the application useful without metadata providers.
- Store user data locally in a portable format.
- Separate provider parsing from shared normalization.
- Share presentation helpers only when their behavior is genuinely identical.
- Prefer small modules and explicit workflows over broad abstractions.
- Preserve manual entry as a first-class workflow.
