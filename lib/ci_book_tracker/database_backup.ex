defmodule CiBookTracker.DatabaseBackup do
  @moduledoc """
  Builds portable backups containing the SQLite database and local cover images.
  """

  alias CiBookTracker.{AppData, Repo}
  alias Exqlite.Sqlite3

  @database_entry "reading_log.db"

  @spec database_path() :: String.t()
  def database_path do
    case Repo.config()[:database] do
      :app_data -> AppData.database_path()
      path when is_binary(path) -> Path.expand(path)
    end
  end

  @spec available_database(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def available_database(path \\ database_path()) do
    if File.regular?(path), do: {:ok, path}, else: {:error, :not_found}
  end

  @spec filename(Date.t()) :: String.t()
  def filename(date \\ Date.utc_today()) do
    "ci_book_tracker_backup_#{Date.to_iso8601(date)}.zip"
  end

  @spec create_archive(keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_archive(opts \\ []) do
    database_path = Keyword.get(opts, :database_path, database_path())
    cover_directory = Keyword.get(opts, :cover_directory, AppData.cover_directory())
    output_path = Keyword.get_lazy(opts, :output_path, &temporary_archive_path/0)

    with {:ok, _database_path} <- available_database(database_path),
         {:ok, snapshot_path} <- snapshot_database(database_path) do
      try do
        with {:ok, entries} <- archive_entries(snapshot_path, cover_directory),
             {:ok, _archive} <- :zip.create(String.to_charlist(output_path), entries) do
          File.chmod(output_path, 0o600)
          {:ok, output_path}
        end
      after
        File.rm(snapshot_path)
      end
    end
    |> case do
      {:ok, ^output_path} = result ->
        result

      {:error, reason} ->
        File.rm(output_path)
        {:error, reason}
    end
  end

  defp snapshot_database(database_path) do
    snapshot_path =
      Path.join(
        System.tmp_dir!(),
        "ci_book_tracker_snapshot_#{System.unique_integer([:positive, :monotonic])}.sqlite3"
      )

    result = create_snapshot_file(database_path, snapshot_path)

    case result do
      {:ok, ^snapshot_path} = success ->
        success

      error ->
        File.rm(snapshot_path)
        error
    end
  end

  defp create_snapshot_file(database_path, snapshot_path) do
    with {:ok, connection} <- Sqlite3.open(database_path, mode: :readonly) do
      try do
        with {:ok, statement} <- Sqlite3.prepare(connection, "VACUUM INTO ?") do
          try do
            with :ok <- Sqlite3.bind(statement, [snapshot_path]),
                 :done <- Sqlite3.step(connection, statement) do
              {:ok, snapshot_path}
            end
          after
            Sqlite3.release(connection, statement)
          end
        end
      after
        Sqlite3.close(connection)
      end
    end
  rescue
    _error -> {:error, :snapshot_failed}
  end

  defp archive_entries(database_path, cover_directory) do
    with {:ok, database} <- File.read(database_path),
         {:ok, covers} <- cover_entries(cover_directory) do
      {:ok, [{String.to_charlist(@database_entry), database} | covers]}
    end
  end

  defp cover_entries(cover_directory) do
    case File.ls(cover_directory) do
      {:ok, filenames} ->
        filenames
        |> Enum.sort()
        |> Enum.reduce_while({:ok, []}, fn filename, {:ok, entries} ->
          path = Path.join(cover_directory, filename)

          if File.regular?(path) do
            case File.read(path) do
              {:ok, contents} ->
                entry_name = String.to_charlist("covers/#{Path.basename(filename)}")
                {:cont, {:ok, [{entry_name, contents} | entries]}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          else
            {:cont, {:ok, entries}}
          end
        end)
        |> case do
          {:ok, entries} -> {:ok, Enum.reverse(entries)}
          error -> error
        end

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp temporary_archive_path do
    Path.join(
      System.tmp_dir!(),
      "ci_book_tracker_backup_#{System.unique_integer([:positive, :monotonic])}.zip"
    )
  end
end
