defmodule CiBookTracker.DatabaseRestoreTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.{DatabaseBackup, DatabaseRestore, DatabaseValidation}
  alias Exqlite.Sqlite3

  test "validates compatible CI Book Tracker databases" do
    path = temporary_path("valid")
    create_database(path)
    on_exit(fn -> File.rm(path) end)

    assert :ok = DatabaseValidation.validate(path)
  end

  test "rejects invalid and structurally incompatible files" do
    text_path = temporary_path("text")
    File.write!(text_path, "not sqlite")

    missing_path = temporary_path("missing")
    create_database(missing_path, tables: ["reading_logs"])

    on_exit(fn ->
      File.rm(text_path)
      File.rm(missing_path)
    end)

    assert {:error, :not_sqlite} = DatabaseValidation.validate(text_path)
    assert {:error, {:missing_tables, tables}} = DatabaseValidation.validate(missing_path)
    assert "books" in tables
  end

  test "replaces the database and creates a timestamped safety backup" do
    directory = temporary_directory()
    target = Path.join(directory, "reading_log.db")
    source = Path.join(directory, "restore.sqlite3")
    backups = Path.join(directory, "backups")
    File.mkdir_p!(directory)
    create_database(target, marker: "current")
    create_database(source, marker: "restored")
    on_exit(fn -> File.rm_rf(directory) end)

    assert {:ok, %{backup_path: backup_path}} =
             DatabaseRestore.restore(source,
               target_path: target,
               backup_directory: backups,
               manage_repo?: false,
               now: ~U[2026-06-08 14:30:45Z]
             )

    assert Path.basename(backup_path) ==
             "ci_book_tracker_pre_restore_2026-06-08_14-30-45.zip"

    assert marker(target) == "restored"
    assert backup_marker(backup_path) == "current"
  end

  test "stages and restores portable archives with their cover files" do
    directory = temporary_directory()
    target = Path.join(directory, "reading_log.db")
    source = Path.join(directory, "source.db")
    target_covers = Path.join(directory, "covers")
    source_covers = Path.join(directory, "source_covers")
    archive = Path.join(directory, "portable.zip")
    File.mkdir_p!(target_covers)
    File.mkdir_p!(source_covers)
    create_database(target, marker: "current")
    create_database(source, marker: "restored")
    File.write!(Path.join(target_covers, "old.jpg"), "old cover")
    File.write!(Path.join(source_covers, "new.jpg"), "new cover")
    on_exit(fn -> File.rm_rf(directory) end)

    assert {:ok, ^archive} =
             DatabaseBackup.create_archive(
               database_path: source,
               cover_directory: source_covers,
               output_path: archive
             )

    assert {:ok, staged} = DatabaseRestore.stage(archive)
    on_exit(fn -> DatabaseRestore.cleanup_stage(staged) end)

    assert {:ok, %{backup_path: backup_path}} =
             DatabaseRestore.restore(staged,
               target_path: target,
               cover_directory: target_covers,
               backup_directory: Path.join(directory, "backups"),
               manage_repo?: false
             )

    assert marker(target) == "restored"
    assert File.read!(Path.join(target_covers, "new.jpg")) == "new cover"
    refute File.exists?(Path.join(target_covers, "old.jpg"))

    assert {:ok, safety_files} = :zip.extract(String.to_charlist(backup_path), [:memory])
    assert {~c"covers/old.jpg", "old cover"} in safety_files
  end

  test "rejects archives with paths outside the backup layout" do
    path = temporary_path("unsafe") <> ".zip"

    assert {:ok, _path} =
             :zip.create(String.to_charlist(path), [
               {~c"reading_log.db", "database"},
               {~c"../outside.jpg", "cover"}
             ])

    on_exit(fn -> File.rm(path) end)
    assert {:error, :unsafe_archive} = DatabaseRestore.stage(path)
  end

  defp create_database(path, opts \\ []) do
    tables =
      Keyword.get(opts, :tables, ~w(reading_logs books provider_settings schema_migrations))

    marker = Keyword.get(opts, :marker)
    {:ok, connection} = Sqlite3.open(path)

    Enum.each(tables, fn
      "schema_migrations" ->
        :ok =
          Sqlite3.execute(
            connection,
            "CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY)"
          )

        Enum.each(DatabaseValidation.expected_migration_versions(), fn version ->
          :ok =
            Sqlite3.execute(
              connection,
              "INSERT INTO schema_migrations (version) VALUES (#{version})"
            )
        end)

      table ->
        :ok = Sqlite3.execute(connection, "CREATE TABLE #{table} (id TEXT PRIMARY KEY)")
    end)

    if marker do
      :ok = Sqlite3.execute(connection, "CREATE TABLE restore_marker (value TEXT)")
      :ok = Sqlite3.execute(connection, "INSERT INTO restore_marker VALUES ('#{marker}')")
    end

    :ok = Sqlite3.close(connection)
  end

  defp marker(path) do
    {:ok, connection} = Sqlite3.open(path, mode: :readonly)
    {:ok, statement} = Sqlite3.prepare(connection, "SELECT value FROM restore_marker")
    {:ok, [[marker]]} = Sqlite3.fetch_all(connection, statement)
    :ok = Sqlite3.release(connection, statement)
    :ok = Sqlite3.close(connection)
    marker
  end

  defp backup_marker(path) do
    {:ok, files} = :zip.extract(String.to_charlist(path), [:memory])
    {~c"reading_log.db", database} = List.keyfind(files, ~c"reading_log.db", 0)
    database_path = temporary_path("backup_marker")
    File.write!(database_path, database)

    try do
      marker(database_path)
    after
      File.rm(database_path)
    end
  end

  defp temporary_path(label) do
    Path.join(
      System.tmp_dir!(),
      "ci_book_tracker_restore_#{label}_#{System.unique_integer([:positive])}.sqlite3"
    )
  end

  defp temporary_directory do
    Path.join(
      System.tmp_dir!(),
      "ci_book_tracker_restore_#{System.unique_integer([:positive])}"
    )
  end
end
