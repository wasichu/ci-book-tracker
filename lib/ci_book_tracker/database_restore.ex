defmodule CiBookTracker.DatabaseRestore do
  @moduledoc false

  alias CiBookTracker.DatabaseBackup
  alias Exqlite.Sqlite3

  @expected_tables ~w(books provider_settings reading_logs schema_migrations)
  @migration_versions [
    20_260_607_124_955,
    20_260_607_141_002,
    20_260_607_142_500,
    20_260_608_120_000,
    20_260_608_131_832
  ]

  @type validation_error ::
          :not_readable
          | :not_sqlite
          | :integrity_check_failed
          | {:missing_tables, [String.t()]}
          | :incompatible_migrations

  @spec validate(String.t()) :: :ok | {:error, validation_error()}
  def validate(path) do
    with true <- File.regular?(path) || {:error, :not_readable},
         {:ok, connection} <- Sqlite3.open(path, mode: :readonly) do
      try do
        with :ok <- validate_integrity(connection),
             :ok <- validate_tables(connection),
             :ok <- validate_migrations(connection) do
          :ok
        end
      after
        Sqlite3.close(connection)
      end
    else
      {:error, :not_readable} = error -> error
      {:error, _reason} -> {:error, :not_sqlite}
    end
  rescue
    _error -> {:error, :not_sqlite}
  end

  @spec stage(String.t()) :: {:ok, String.t()} | {:error, validation_error() | term()}
  def stage(source_path) do
    with :ok <- validate(source_path) do
      staged_path =
        Path.join(
          System.tmp_dir!(),
          "ci_book_tracker_restore_#{System.unique_integer([:positive, :monotonic])}.sqlite3"
        )

      case File.cp(source_path, staged_path) do
        :ok ->
          File.chmod(staged_path, 0o600)
          {:ok, staged_path}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @spec restore(String.t(), keyword()) ::
          {:ok, %{backup_path: String.t()}} | {:error, term()}
  def restore(staged_path, opts \\ []) do
    target_path = Keyword.get(opts, :target_path, DatabaseBackup.database_path())
    backup_directory = Keyword.get(opts, :backup_directory, default_backup_directory(target_path))
    now = Keyword.get(opts, :now, DateTime.utc_now())
    manage_repo? = Keyword.get(opts, :manage_repo?, target_path == DatabaseBackup.database_path())

    with :ok <- validate(staged_path),
         :ok <- File.mkdir_p(backup_directory),
         {:ok, replacement_path} <- copy_replacement(staged_path, target_path) do
      perform_restore(replacement_path, target_path, backup_directory, now, manage_repo?)
    end
  end

  def safety_backup_filename(now \\ DateTime.utc_now()) do
    timestamp =
      now
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y-%m-%d_%H-%M-%S")

    "ci_book_tracker_pre_restore_#{timestamp}.sqlite3"
  end

  def error_message(:not_readable), do: "The selected file could not be read."
  def error_message(:not_sqlite), do: "The selected file is not a readable SQLite database."

  def error_message(:integrity_check_failed),
    do: "The selected database did not pass SQLite's integrity check."

  def error_message({:missing_tables, tables}),
    do: "The database is missing required tables: #{Enum.join(tables, ", ")}."

  def error_message(:incompatible_migrations),
    do: "The database schema is not compatible with this version of CI Book Tracker."

  def error_message(_reason), do: "The database could not be restored."

  defp validate_integrity(connection) do
    case query(connection, "PRAGMA integrity_check") do
      {:ok, [["ok"]]} -> :ok
      {:ok, _rows} -> {:error, :integrity_check_failed}
      {:error, _reason} -> {:error, :not_sqlite}
    end
  end

  defp validate_tables(connection) do
    with {:ok, rows} <-
           query(connection, "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name") do
      tables = Enum.map(rows, &List.first/1)
      missing = @expected_tables -- tables
      if missing == [], do: :ok, else: {:error, {:missing_tables, missing}}
    else
      {:error, _reason} -> {:error, :not_sqlite}
    end
  end

  defp validate_migrations(connection) do
    case query(connection, "SELECT version FROM schema_migrations ORDER BY version") do
      {:ok, rows} ->
        versions = Enum.map(rows, fn [version] -> normalize_version(version) end)
        if versions == @migration_versions, do: :ok, else: {:error, :incompatible_migrations}

      {:error, _reason} ->
        {:error, :incompatible_migrations}
    end
  end

  defp normalize_version(version) when is_integer(version), do: version

  defp normalize_version(version) when is_binary(version) do
    case Integer.parse(version) do
      {integer, ""} -> integer
      _other -> version
    end
  end

  defp query(connection, sql) do
    with {:ok, statement} <- Sqlite3.prepare(connection, sql) do
      try do
        Sqlite3.fetch_all(connection, statement)
      after
        Sqlite3.release(connection, statement)
      end
    end
  end

  defp copy_replacement(source_path, target_path) do
    replacement_path =
      Path.join(
        Path.dirname(target_path),
        ".ci_book_tracker_restore_#{System.unique_integer([:positive, :monotonic])}.sqlite3"
      )

    case File.cp(source_path, replacement_path) do
      :ok ->
        File.chmod(replacement_path, 0o600)
        {:ok, replacement_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_restore(replacement_path, target_path, backup_directory, now, manage_repo?) do
    case prepare_repo(manage_repo?) do
      {:ok, repo_stopped?} ->
        try do
          backup_path = Path.join(backup_directory, safety_backup_filename(now))

          with :ok <- backup_current_database(target_path, backup_path),
               :ok <- replace_database(replacement_path, target_path) do
            remove_sidecars(target_path)
            {:ok, %{backup_path: backup_path}}
          end
        after
          File.rm(replacement_path)
          if repo_stopped?, do: restart_repo()
        end

      {:error, reason} ->
        File.rm(replacement_path)
        {:error, reason}
    end
  end

  defp prepare_repo(false), do: {:ok, false}

  defp prepare_repo(true) do
    if Process.whereis(CiBookTracker.Repo) do
      with {:ok, _result} <-
             Ecto.Adapters.SQL.query(
               CiBookTracker.Repo,
               "PRAGMA wal_checkpoint(TRUNCATE)",
               []
             ),
           :ok <- Supervisor.terminate_child(CiBookTracker.Supervisor, CiBookTracker.Repo) do
        {:ok, true}
      end
    else
      {:ok, false}
    end
  end

  defp backup_current_database(target_path, backup_path) do
    if File.regular?(target_path) do
      File.cp(target_path, backup_path)
    else
      {:error, :current_database_not_found}
    end
  end

  defp replace_database(replacement_path, target_path) do
    case File.rename(replacement_path, target_path) do
      :ok -> :ok
      {:error, :eexist} -> replace_database_with_rollback(replacement_path, target_path)
      {:error, reason} -> {:error, reason}
    end
  end

  defp replace_database_with_rollback(replacement_path, target_path) do
    displaced_path = target_path <> ".pre_restore_swap"

    with :ok <- File.rename(target_path, displaced_path) do
      case File.rename(replacement_path, target_path) do
        :ok ->
          File.rm(displaced_path)
          :ok

        {:error, reason} ->
          File.rename(displaced_path, target_path)
          {:error, reason}
      end
    end
  end

  defp restart_repo do
    case Supervisor.restart_child(CiBookTracker.Supervisor, CiBookTracker.Repo) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, :running} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp remove_sidecars(target_path) do
    File.rm(target_path <> "-wal")
    File.rm(target_path <> "-shm")
    :ok
  end

  defp default_backup_directory(target_path), do: Path.join(Path.dirname(target_path), "backups")
end
