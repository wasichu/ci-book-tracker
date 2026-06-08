defmodule CiBookTracker.DatabaseBackupTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.DatabaseBackup

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
             "ci_book_tracker_backup_2026-06-08.sqlite3"
  end
end
