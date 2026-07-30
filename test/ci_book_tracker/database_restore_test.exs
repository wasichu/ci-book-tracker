defmodule CiBookTracker.DatabaseRestoreTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.DatabaseRestore
  alias Exqlite.Sqlite3

  @versions [
    20_260_607_124_955,
    20_260_607_141_002,
    20_260_607_142_500,
    20_260_608_120_000,
    20_260_608_131_832,
    20_260_730_120_000
  ]

  test "validates compatible CI Book Tracker databases" do
    path = temporary_path("valid")
    create_database(path)
    on_exit(fn -> File.rm(path) end)

    assert :ok = DatabaseRestore.validate(path)
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

    assert {:error, :not_sqlite} = DatabaseRestore.validate(text_path)
    assert {:error, {:missing_tables, tables}} = DatabaseRestore.validate(missing_path)
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
             "ci_book_tracker_pre_restore_2026-06-08_14-30-45.sqlite3"

    assert marker(target) == "restored"
    assert marker(backup_path) == "current"
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

        Enum.each(@versions, fn version ->
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
