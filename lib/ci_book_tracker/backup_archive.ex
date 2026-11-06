defmodule CiBookTracker.BackupArchive do
  @moduledoc false

  @database_entry "reading_log.db"
  @max_cover_bytes 8 * 1024 * 1024
  @max_archive_bytes 250_000_000

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

  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_archive_bytes

  @spec limit_label() :: String.t()
  def limit_label, do: "#{div(@max_archive_bytes, 1_000_000)} MB"

  @spec validate_file_size(String.t()) :: :ok | {:error, atom()}
  def validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{type: :regular, size: size}} when size <= @max_archive_bytes -> :ok
      {:ok, %{type: :regular}} -> {:error, :backup_too_large}
      _ -> {:error, :not_readable}
    end
  end

  @spec create(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create(output_path, database_path, cover_directory) do
    with {:ok, entries} <- archive_entries(database_path, cover_directory),
         :ok <-
           validate_files(
             Enum.map(entries, fn {name, data} -> {to_string(name), byte_size(data)} end)
           ),
         {:ok, _archive} <- :zip.create(String.to_charlist(output_path), entries) do
      case validate_file_size(output_path) do
        :ok ->
          {:ok, output_path}

        error ->
          File.rm(output_path)
          error
      end
    end
  end

  @spec stage(String.t(), (String.t() -> :ok | {:error, term()})) ::
          {:ok, StagedBackup.t()} | {:error, term()}
  def stage(source_path, validate_database) do
    with :ok <- validate_file_size(source_path),
         {:ok, table} <- zip_table(source_path),
         :ok <- validate_table(table),
         {:ok, files} <- extract(source_path) do
      write_stage(files, validate_database)
    end
  end

  @spec cleanup(StagedBackup.t()) :: :ok
  def cleanup(%StagedBackup{temporary_directory: directory}) do
    File.rm_rf(directory)
    :ok
  end

  defp archive_entries(database_path, cover_directory) do
    with {:ok, covers} <- cover_paths(cover_directory),
         sources = [{@database_entry, database_path} | covers],
         :ok <- validate_source_sizes(sources) do
      Enum.reduce_while(sources, {:ok, []}, fn {name, path}, {:ok, entries} ->
        case File.read(path) do
          {:ok, contents} -> {:cont, {:ok, [{String.to_charlist(name), contents} | entries]}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, entries} -> {:ok, Enum.reverse(entries)}
        error -> error
      end
    end
  end

  # Check sizes before loading the database and covers into memory.
  defp validate_source_sizes(sources) do
    Enum.reduce_while(sources, {:ok, []}, fn {name, path}, {:ok, sizes} ->
      case File.stat(path) do
        {:ok, %{size: size}} -> {:cont, {:ok, [{name, size} | sizes]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, sizes} -> validate_files(sizes)
      error -> error
    end
  end

  defp cover_paths(directory) do
    case File.ls(directory) do
      {:ok, filenames} ->
        covers =
          filenames
          |> Enum.sort()
          |> Enum.map(&{"covers/#{Path.basename(&1)}", Path.join(directory, &1)})
          |> Enum.filter(fn {_name, path} -> File.regular?(path) end)

        {:ok, covers}

      {:error, :enoent} ->
        {:ok, []}

      error ->
        error
    end
  end

  defp zip_table(source_path) do
    case :zip.table(String.to_charlist(source_path)) do
      {:ok, table} -> {:ok, table}
      {:error, _reason} -> {:error, :not_sqlite}
    end
  end

  defp validate_table(table) do
    files =
      Enum.flat_map(table, fn
        {:zip_file, name, file_info, _comment, _offset, _compressed_size} ->
          [{to_string(name), elem(file_info, 1)}]

        _comment ->
          []
      end)

    validate_files(files)
  end

  defp validate_files(files) do
    names = Enum.map(files, &elem(&1, 0))
    total_size = Enum.sum(Enum.map(files, &elem(&1, 1)))

    cond do
      Enum.count(names, &(&1 == @database_entry)) != 1 ->
        {:error, :not_backup}

      length(names) != length(Enum.uniq(names)) ->
        {:error, :unsafe_archive}

      total_size > @max_archive_bytes ->
        {:error, :backup_too_large}

      Enum.any?(files, fn {name, size} -> !valid_entry?(name, size) end) ->
        {:error, :unsafe_archive}

      true ->
        :ok
    end
  end

  defp valid_entry?(@database_entry, size), do: size > 0

  defp valid_entry?("covers/" <> filename, size) do
    filename != "" && filename == Path.basename(filename) && size in 1..@max_cover_bytes
  end

  defp valid_entry?(_name, _size), do: false

  defp extract(source_path) do
    case :zip.extract(String.to_charlist(source_path), [:memory]) do
      {:ok, files} ->
        {:ok, Enum.map(files, fn {name, contents} -> {to_string(name), contents} end)}

      {:error, _reason} ->
        {:error, :not_backup}
    end
  end

  defp write_stage(files, validate_database) do
    temporary_directory =
      Path.join(
        System.tmp_dir!(),
        "ci_book_tracker_restore_#{System.unique_integer([:positive, :monotonic])}"
      )

    database_path = Path.join(temporary_directory, @database_entry)
    cover_directory = Path.join(temporary_directory, "covers")

    with :ok <- File.mkdir_p(cover_directory),
         :ok <- write_files(files, temporary_directory),
         :ok <- validate_database.(database_path) do
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

  defp write_files(files, temporary_directory) do
    Enum.reduce_while(files, :ok, fn {name, contents}, :ok ->
      path = Path.join(temporary_directory, name)
      File.mkdir_p!(Path.dirname(path))

      case File.write(path, contents) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
