defmodule CiBookTracker.DatabaseRestore do
  @moduledoc false

  alias CiBookTracker.{AppData, BackupArchive, DatabaseBackup, DatabaseValidation}
  alias CiBookTracker.BackupArchive.StagedBackup
  alias CiBookTracker.DatabaseRestore.Migration

  @type validation_error ::
          :not_readable
          | :not_sqlite
          | :not_backup
          | :unsafe_archive
          | :backup_too_large
          | :integrity_check_failed
          | {:missing_tables, [String.t()]}
          | :incompatible_migrations
          | :migration_failed

  @spec validate(String.t()) :: :ok | {:error, validation_error()}
  defdelegate validate(path), to: DatabaseValidation

  @spec stage(String.t()) ::
          {:ok, String.t() | StagedBackup.t()} | {:error, validation_error() | term()}
  def stage(source_path) do
    case DatabaseValidation.validate(source_path, allow_older?: true) do
      :ok -> stage_database(source_path)
      {:error, :not_sqlite} -> BackupArchive.stage(source_path, &Migration.prepare/1)
      {:error, reason} -> {:error, reason}
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
    runtime = Keyword.get(opts, :runtime, CiBookTracker.DatabaseRestore.Runtime)
    file_system = Keyword.get(opts, :file_system, File)

    %{database_path: staged_path, cover_directory: staged_covers} =
      staged_backup_paths(staged_backup)

    with :ok <- validate(staged_path),
         :ok <- File.mkdir_p(backup_directory),
         {:ok, replacement_path} <- copy_replacement(staged_path, target_path) do
      perform_restore(replacement_path, staged_covers, %{
        target_path: target_path,
        cover_directory: target_cover_directory,
        backup_directory: backup_directory,
        now: now,
        manage_repo?: manage_repo?,
        runtime: runtime,
        file_system: file_system
      })
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

  def error_message(:migration_failed),
    do: "This older backup could not be upgraded. Your backup and current data have not changed."

  def error_message(:incompatible_migrations),
    do: "The database schema is not compatible with this version of CI Book Tracker."

  def error_message({:repo_restart_failed, {:ok, %{backup_path: path}}, _reason}),
    do:
      "Your backup was restored, but the database could not restart. Please restart CI Book Tracker. Safety backup: #{path}"

  def error_message({:repo_restart_failed, {:error, reason}, _restart_reason}),
    do: "#{error_message(reason)} The database could not restart. Please restart CI Book Tracker."

  def error_message({:rollback_failed, _reason, _rollback_reason, path}),
    do:
      "Restore failed and automatic recovery could not finish. Your previous data is preserved at: #{path}. Restart only after recovering this file."

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

        case Migration.prepare(staged_path) do
          :ok ->
            {:ok, staged_path}

          {:error, reason} ->
            cleanup_stage(staged_path)
            {:error, reason}
        end

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

  defp perform_restore(replacement_path, staged_covers, context) do
    %{manage_repo?: manage_repo?, runtime: runtime} = context

    try do
      case runtime.prepare(manage_repo?) do
        {:ok, repo_stopped?} ->
          result =
            try do
              replace_data(replacement_path, staged_covers, context)
            rescue
              error -> {:error, {:restore_exception, Exception.message(error)}}
            end

          restart? = repo_stopped? && !recovery_failed?(result)

          case if(restart?, do: runtime.restart(), else: :ok) do
            :ok -> result
            {:error, reason} -> {:error, {:repo_restart_failed, result, reason}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    after
      File.rm(replacement_path)
    end
  end

  defp recovery_failed?({:error, {:rollback_failed, _, _, _}}), do: true
  defp recovery_failed?(_result), do: false

  defp replace_data(replacement_path, staged_covers, context) do
    %{
      target_path: target_path,
      cover_directory: target_cover_directory,
      backup_directory: backup_directory,
      now: now,
      file_system: file_system
    } = context

    backup_path = Path.join(backup_directory, safety_backup_filename(now))

    with :ok <- backup_current_data(target_path, target_cover_directory, backup_path),
         {:ok, displaced} <- swap_database(replacement_path, target_path, file_system) do
      case replace_cover_directory(staged_covers, target_cover_directory, file_system) do
        :ok ->
          File.rm(displaced)
          remove_sidecars(target_path)
          {:ok, %{backup_path: backup_path}}

        {:error, reason} ->
          case file_system.rename(displaced, target_path) do
            :ok ->
              {:error, reason}

            {:error, rollback_reason} ->
              {:error, {:rollback_failed, reason, rollback_reason, displaced}}
          end
      end
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

  defp replace_cover_directory(nil, _target_directory, _file_system), do: :ok

  defp replace_cover_directory(source_directory, target_directory, file_system) do
    suffix = System.unique_integer([:positive, :monotonic])
    replacement_directory = "#{target_directory}.restore_#{suffix}"
    displaced_directory = "#{target_directory}.pre_restore_#{suffix}"

    with {:ok, _files} <- File.cp_r(source_directory, replacement_directory),
         :ok <- displace_cover_directory(target_directory, displaced_directory, file_system) do
      case file_system.rename(replacement_directory, target_directory) do
        :ok ->
          File.rm_rf(displaced_directory)
          :ok

        {:error, reason} ->
          rollback =
            restore_displaced_cover_directory(target_directory, displaced_directory, file_system)

          File.rm_rf(replacement_directory)

          case rollback do
            :ok ->
              {:error, reason}

            {:error, rollback_reason} ->
              {:error, {:rollback_failed, reason, rollback_reason, displaced_directory}}
          end
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

  defp displace_cover_directory(target_directory, displaced_directory, file_system) do
    if File.dir?(target_directory) do
      file_system.rename(target_directory, displaced_directory)
    else
      :ok
    end
  end

  defp restore_displaced_cover_directory(target_directory, displaced_directory, file_system) do
    if File.dir?(displaced_directory),
      do: file_system.rename(displaced_directory, target_directory),
      else: :ok
  end

  defp swap_database(replacement_path, target_path, file_system) do
    displaced = "#{target_path}.pre_restore_#{System.unique_integer([:positive, :monotonic])}"

    with :ok <- file_system.rename(target_path, displaced) do
      case file_system.rename(replacement_path, target_path) do
        :ok ->
          {:ok, displaced}

        {:error, reason} ->
          case file_system.rename(displaced, target_path) do
            :ok ->
              {:error, reason}

            {:error, rollback_reason} ->
              {:error, {:rollback_failed, reason, rollback_reason, displaced}}
          end
      end
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
