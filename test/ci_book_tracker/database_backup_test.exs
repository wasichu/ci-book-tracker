defmodule CiBookTracker.DatabaseBackupTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.DatabaseBackup
  alias Exqlite.Sqlite3

  test "resolves the database configured for the running Repo" do
    assert DatabaseBackup.database_path() ==
             CiBookTracker.Repo.config()
             |> Keyword.fetch!(:database)
             |> Path.expand()
  end

  test "reports whether a configured database file is available" do
    path =
      Path.join(
        System.tmp_dir!(),
        "ci_book_tracker_backup_#{System.unique_integer([:positive])}.sqlite3"
      )

    refute File.exists?(path)
    assert {:error, :not_found} = DatabaseBackup.available_database(path)

    File.write!(path, "database")
    on_exit(fn -> File.rm(path) end)

    assert {:ok, ^path} = DatabaseBackup.available_database(path)
  end

  test "builds a clear dated backup filename" do
    assert DatabaseBackup.filename(~D[2026-06-08]) ==
             "ci_book_tracker_backup_2026-06-08.zip"
  end

  test "creates a portable archive containing the database and covers" do
    directory =
      Path.join(
        System.tmp_dir!(),
        "ci_book_tracker_backup_test_#{System.unique_integer([:positive])}"
      )

    database_path = Path.join(directory, "source.db")
    cover_directory = Path.join(directory, "covers")
    output_path = Path.join(directory, "backup.zip")
    File.mkdir_p!(cover_directory)
    {:ok, connection} = Sqlite3.open(database_path)
    :ok = Sqlite3.execute(connection, "CREATE TABLE marker (value TEXT)")
    :ok = Sqlite3.execute(connection, "INSERT INTO marker VALUES ('database')")
    :ok = Sqlite3.close(connection)
    File.write!(Path.join(cover_directory, "cover.jpg"), "cover")
    on_exit(fn -> File.rm_rf(directory) end)

    assert {:ok, ^output_path} =
             DatabaseBackup.create_archive(
               database_path: database_path,
               cover_directory: cover_directory,
               output_path: output_path
             )

    assert {:ok, files} = :zip.extract(String.to_charlist(output_path), [:memory])
    assert List.keymember?(files, ~c"reading_log.db", 0)
    assert {~c"covers/cover.jpg", "cover"} in files
  end
end
