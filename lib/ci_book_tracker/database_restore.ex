defmodule CiBookTracker.DatabaseRestore do
  @moduledoc false

  alias CiBookTracker.{AppData, BackupArchive, DatabaseBackup, DatabaseValidation}
  alias CiBookTracker.BackupArchive.StagedBackup

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
  defdelegate validate(path), to: DatabaseValidation

  @spec stage(String.t()) ::
          {:ok, String.t() | StagedBackup.t()} | {:error, validation_error() | term()}
  def stage(source_path) do
    case validate(source_path) do
      :ok -> stage_database(source_path)
      {:error, _database_error} -> BackupArchive.stage(source_path, &validate/1)
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

  @doc false
  defdelegate expected_migration_versions(), to: DatabaseValidation

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

  @spec cleanup_stage(String.t() | StagedBackup.t() | nil) :: :ok
  def cleanup_stage(%StagedBackup{} = staged), do: BackupArchive.cleanup(staged)

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
