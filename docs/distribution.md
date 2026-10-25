# Native releases and Homebrew

CI Book Tracker uses standard Phoenix releases with bundled Erlang/Elixir.
Users do not need Mix, Elixir, Erlang, Node, or a database server. Releases are
directories containing executables, libraries, assets, and migrations, rather
than a single executable.

## Supported package targets

| Archive target | Build runner | Runtime requirements |
| --- | --- | --- |
| `macos-arm64` | `macos-15` | Apple Silicon, macOS 15+, standard `/opt/homebrew` installation, Homebrew OpenSSL 3 and ncurses |
| `macos-x86_64` | `macos-15-intel` | Intel, macOS 15+, standard `/usr/local` installation, Homebrew OpenSSL 3 and ncurses |
| `linux-x86_64` | `ubuntu-24.04` | x86-64, Ubuntu 24.04 or compatible glibc 2.39+, OpenSSL 3, ncurses 6, zlib and C++ runtime |

These packages include ERTS but still depend on platform libraries. They are
not universal macOS binaries or static Linux binaries. Alpine/musl and Linux
ARM are not currently packaged. On Ubuntu, install runtime libraries with
`sudo apt install libssl3t64 libncurses6 libtinfo6 zlib1g libstdc++6`.

For Homebrew installations, the formula installs its library dependencies and
adjusts the Linux executables to use Homebrew's OpenSSL, ncurses, and zlib.
The direct Linux archive continues to use the system libraries listed above.

## Local build and validation

Use the toolchain pinned in `.tool-versions`, then run:

```sh
mix deps.get --only prod --check-locked
MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix assets.setup
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
python3 scripts/smoke_release.py _build/prod/rel/ci_book_tracker
```

The smoke test uses a temporary data directory and an available local port.
It checks the packaged version command, first boot, SQLite migrations, HTTP
response and bundled assets, secret file permissions, and persistence across
two starts. CI also extracts the archive to a different path containing a space
before testing.

Start the release normally with:

```sh
_build/prod/rel/ci_book_tracker/bin/ci-book-tracker
```

Visit `http://localhost:4000`. Stop with Ctrl-C (or SIGTERM when supervised).
The packaged command also supports `--help` and `--version`. To rebuild an
existing release, add `--overwrite` to `mix release`.

## Local configuration and secrets

Production starts the HTTP server automatically, binds only to `127.0.0.1`,
and uses `http://localhost:4000`. It runs pending database migrations before
starting the endpoint; a migration failure prevents the server from starting.
Erlang distribution is disabled by default, so the bundled runtime does not
open clustering ports or depend on a machine hostname.
Development and test database setup retain their existing Mix workflows.

| Variable | Default / meaning |
| --- | --- |
| `PORT` | `4000` |
| `PHX_HOST` | `localhost`; URL hostname, does not change the listening interface |
| `CI_BOOK_TRACKER_DATA_DIR` | Existing platform data directory; moves the default database, covers, and saved session secret together |
| `DATABASE_PATH` | Override only the database path |
| `SECRET_KEY_BASE` | Optional override, at least 64 bytes; otherwise generated and persisted automatically |
| `PHX_SERVER` | `false` or `0` disables the production HTTP server |
| `POOL_SIZE` | SQLite pool size, defaults to `10` |

Phoenix uses `SECRET_KEY_BASE` to derive keys for session/cookie signing and
encryption. It is not a metadata provider credential, and it does not encrypt
the SQLite database. Each installation generates its own random secret and
saves it as `secret_key_base` in the data directory with owner-only read/write
permissions (`0600`). The key stays stable through restarts and upgrades.
Concurrent first starts cannot replace an already saved key. An unreadable or
invalid saved key fails startup instead of silently replacing it.

Changing or deleting the key invalidates existing signed sessions. Application
backup ZIPs contain the database and covers, not this key; moving a backup to
another installation therefore starts with fresh browser sessions.

## Publishing a version

1. Run `mix precommit`, update the version in `mix.exs` as appropriate, and
   commit the changes. Back up personal data before testing upgrades.
2. Push a matching stable tag, for example `v0.2.0` for version `0.2.0`.
3. The release workflow builds and smoke-tests all three targets. Only after
   all succeed does it create a **draft** GitHub release containing the three
   archives, `SHA256SUMS`, and a generated `ci-book-tracker.rb` formula with
   checksums for those exact archives. Tag/version mismatches fail the build.
4. Review the draft and publish it. Draft assets are not publicly installable.
5. In a public repository named `wasichu/homebrew-tap`, place the generated
   formula at `Formula/ci-book-tracker.rb`, then test and commit it. The template
   in this application repository is not itself an installable formula.

```sh
brew tap wasichu/tap
brew install wasichu/tap/ci-book-tracker
brew test wasichu/tap/ci-book-tracker
brew audit --strict wasichu/tap/ci-book-tracker
ci-book-tracker
```

The tap must exist and the release must be public before those install commands
work. No cross-repository token is required: the generated formula is copied
to the tap after reviewing each release. `workflow_dispatch` builds test
artifacts without publishing a release. Relevant pull requests also build all
targets without publishing.

For future versions, publish the new release and replace the tap formula with
the newly generated one. Users can then run `brew update` and
`brew upgrade ci-book-tracker`. Quit the running application before upgrading,
then start it again. The database, covers, and secret remain outside Homebrew's
versioned installation directory. Foreground operation is the initial supported
mode; a Homebrew background service can be added later.
