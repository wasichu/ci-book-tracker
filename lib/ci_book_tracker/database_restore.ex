defmodule CiBookTracker.DatabaseRestore do
  @moduledoc false

  alias CiBookTracker.{AppData, DatabaseBackup, Repo}
  alias Exqlite.Sqlite3

  @database_entry "reading_log.db"
  @max_cover_bytes 8 * 1024 * 1024
  @max_archive_bytes 250 * 1024 * 1024
  @expected_tables ~w(books provider_settings reading_logs schema_migrations)

  defmodule StagedBackup do
    @moduledoc false
    @enforce_keys [:database_path, :cover_directory, :temporary_directory]
    defstruct [:database_path, :cover_directory, :temporary_directory]

    @type t :: %__MODULE__{
            database_path: String.t(),
            cover_directory: String.t(),
            temporary_directory: String.t()
          }
  end

  @type validation_error ::
          :not_readable
          | :not_sqlite
          | :not_backup
          | :unsafe_archive
          | :backup_too_large
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

  @spec stage(String.t()) ::
          {:ok, String.t() | StagedBackup.t()} | {:error, validation_error() | term()}
  def stage(source_path) do
    case validate(source_path) do
      :ok -> stage_database(source_path)
      {:error, _database_error} -> stage_archive(source_path)
    end
  end

  @spec restore(String.t() | StagedBackup.t(), keyword()) ::
          {:ok, %{backup_path: String.t()}} | {:error, term()}
  def restore(staged_backup, opts \\ []) do
    target_path = Keyword.get(opts, :target_path, DatabaseBackup.database_path())
    backup_directory = Keyword.get(opts, :backup_directory, default_backup_directory(target_path))

    target_cover_directory =
      Keyword.get(opts, :cover_directory, default_cover_directory(target_path))

    now = Keyword.get(opts, :now, DateTime.utc_now())
    manage_repo? = Keyword.get(opts, :manage_repo?, target_path == DatabaseBackup.database_path())

    %{database_path: staged_path, cover_directory: staged_covers} =
      staged_backup_paths(staged_backup)

    with :ok <- validate(staged_path),
         :ok <- File.mkdir_p(backup_directory),
         {:ok, replacement_path} <- copy_replacement(staged_path, target_path) do
      perform_restore(
        replacement_path,
        staged_covers,
        target_path,
        target_cover_directory,
        backup_directory,
        now,
        manage_repo?
      )
    end
  end

  def safety_backup_filename(now \\ DateTime.utc_now()) do
    timestamp =
      now
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y-%m-%d_%H-%M-%S")

    "ci_book_tracker_pre_restore_#{timestamp}.zip"
  end

  def error_message(:not_readable), do: "The selected file could not be read."
  def error_message(:not_sqlite), do: "The selected file is not a readable SQLite database."
  def error_message(:not_backup), do: "The selected file is not a CI Book Tracker backup."

  def error_message(:unsafe_archive),
    do: "The backup contains an invalid or unsafe file path."

  def error_message(:backup_too_large), do: "The expanded backup is too large to restore."

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

        if versions == expected_migration_versions(),
          do: :ok,
          else: {:error, :incompatible_migrations}

      {:error, _reason} ->
        {:error, :incompatible_migrations}
    end
  end

  @doc false
  def expected_migration_versions do
    Repo
    |> Ecto.Migrator.migrations_path()
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.map(&Path.basename/1)
    |> Enum.map(fn filename ->
      filename
      |> String.split("_", parts: 2)
      |> hd()
      |> String.to_integer()
    end)
    |> Enum.sort()
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

  defp stage_database(source_path) do
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

  defp stage_archive(source_path) do
    with {:ok, table} <- zip_table(source_path),
         :ok <- validate_archive_table(table),
         {:ok, files} <- extract_archive(source_path) do
      write_staged_archive(files)
    end
  end

  defp zip_table(source_path) do
    case :zip.table(String.to_charlist(source_path)) do
      {:ok, table} -> {:ok, table}
      {:error, _reason} -> {:error, :not_sqlite}
    end
  end

  defp validate_archive_table(table) do
    files =
      Enum.flat_map(table, fn
        {:zip_file, name, file_info, _comment, _offset, _compressed_size} ->
          [{to_string(name), elem(file_info, 1)}]

        _comment ->
          []
      end)

    names = Enum.map(files, &elem(&1, 0))
    total_size = Enum.sum(Enum.map(files, &elem(&1, 1)))

    cond do
      Enum.count(names, &(&1 == @database_entry)) != 1 ->
        {:error, :not_backup}

      length(names) != length(Enum.uniq(names)) ->
        {:error, :unsafe_archive}

      total_size > @max_archive_bytes ->
        {:error, :backup_too_large}

      Enum.any?(files, fn {name, size} ->
        !valid_archive_entry?(name, size)
      end) ->
        {:error, :unsafe_archive}

      true ->
        :ok
    end
  end

  defp valid_archive_entry?(@database_entry, size), do: size > 0

  defp valid_archive_entry?("covers/" <> filename, size) do
    filename != "" && filename == Path.basename(filename) && size in 1..@max_cover_bytes
  end

  defp valid_archive_entry?(_name, _size), do: false

  defp extract_archive(source_path) do
    case :zip.extract(String.to_charlist(source_path), [:memory]) do
      {:ok, files} ->
        {:ok, Enum.map(files, fn {name, contents} -> {to_string(name), contents} end)}

      {:error, _reason} ->
        {:error, :not_backup}
    end
  end

  defp write_staged_archive(files) do
    temporary_directory =
      Path.join(
        System.tmp_dir!(),
        "ci_book_tracker_restore_#{System.unique_integer([:positive, :monotonic])}"
      )

    database_path = Path.join(temporary_directory, @database_entry)
    cover_directory = Path.join(temporary_directory, "covers")

    with :ok <- File.mkdir_p(cover_directory),
         :ok <- write_archive_files(files, temporary_directory),
         :ok <- validate(database_path) do
      {:ok,
       %StagedBackup{
         database_path: database_path,
         cover_directory: cover_directory,
         temporary_directory: temporary_directory
       }}
    else
      {:error, reason} ->
        File.rm_rf(temporary_directory)
        {:error, reason}
    end
  end

  defp write_archive_files(files, temporary_directory) do
    Enum.reduce_while(files, :ok, fn {name, contents}, :ok ->
      path = Path.join(temporary_directory, name)
      File.mkdir_p!(Path.dirname(path))

      case File.write(path, contents) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec cleanup_stage(String.t() | StagedBackup.t() | nil) :: :ok
  def cleanup_stage(%StagedBackup{temporary_directory: directory}) do
    File.rm_rf(directory)
    :ok
  end

  def cleanup_stage(path) when is_binary(path) do
    File.rm(path)
    :ok
  end

  def cleanup_stage(nil), do: :ok

  defp staged_backup_paths(%StagedBackup{} = staged) do
    %{database_path: staged.database_path, cover_directory: staged.cover_directory}
  end

  defp staged_backup_paths(path) when is_binary(path) do
    %{database_path: path, cover_directory: nil}
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

  defp perform_restore(
         replacement_path,
         staged_covers,
         target_path,
         target_cover_directory,
         backup_directory,
         now,
         manage_repo?
       ) do
    case prepare_repo(manage_repo?) do
      {:ok, repo_stopped?} ->
        try do
          backup_path = Path.join(backup_directory, safety_backup_filename(now))

          with :ok <-
                 backup_current_data(target_path, target_cover_directory, backup_path),
               {:ok, displaced_database} <- swap_database(replacement_path, target_path) do
            case replace_cover_directory(staged_covers, target_cover_directory) do
              :ok ->
                File.rm(displaced_database)
                remove_sidecars(target_path)
                {:ok, %{backup_path: backup_path}}

              {:error, reason} ->
                rollback_database(displaced_database, target_path)
                {:error, reason}
            end
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

  defp backup_current_data(target_path, cover_directory, backup_path) do
    case DatabaseBackup.create_archive(
           database_path: target_path,
           cover_directory: cover_directory,
           output_path: backup_path
         ) do
      {:ok, ^backup_path} -> :ok
      {:error, :not_found} -> {:error, :current_database_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp replace_cover_directory(nil, _target_directory), do: :ok

  defp replace_cover_directory(source_directory, target_directory) do
    suffix = System.unique_integer([:positive, :monotonic])
    replacement_directory = "#{target_directory}.restore_#{suffix}"
    displaced_directory = "#{target_directory}.pre_restore_#{suffix}"

    with {:ok, _files} <- File.cp_r(source_directory, replacement_directory),
         :ok <- displace_cover_directory(target_directory, displaced_directory) do
      case File.rename(replacement_directory, target_directory) do
        :ok ->
          File.rm_rf(displaced_directory)
          :ok

        {:error, reason} ->
          restore_displaced_cover_directory(target_directory, displaced_directory)
          File.rm_rf(replacement_directory)
          {:error, reason}
      end
    else
      {:error, reason, _file} ->
        File.rm_rf(replacement_directory)
        {:error, reason}

      {:error, reason} ->
        File.rm_rf(replacement_directory)
        {:error, reason}
    end
  end

  defp displace_cover_directory(target_directory, displaced_directory) do
    if File.dir?(target_directory) do
      File.rename(target_directory, displaced_directory)
    else
      :ok
    end
  end

  defp restore_displaced_cover_directory(target_directory, displaced_directory) do
    if File.dir?(displaced_directory), do: File.rename(displaced_directory, target_directory)
    :ok
  end

  defp swap_database(replacement_path, target_path) do
    displaced_path =
      "#{target_path}.pre_restore_#{System.unique_integer([:positive, :monotonic])}"

    with :ok <- File.rename(target_path, displaced_path) do
      case File.rename(replacement_path, target_path) do
        :ok ->
          {:ok, displaced_path}

        {:error, reason} ->
          File.rename(displaced_path, target_path)
          {:error, reason}
      end
    end
  end

  defp rollback_database(displaced_path, target_path) do
    File.rm(target_path)
    File.rename(displaced_path, target_path)
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

  defp default_cover_directory(target_path) do
    if Path.expand(target_path) == Path.expand(DatabaseBackup.database_path()) do
      AppData.cover_directory()
    else
      Path.join(Path.dirname(target_path), "covers")
    end
  end
end
