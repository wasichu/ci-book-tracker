defmodule CiBookTracker.DatabaseValidation do
  @moduledoc false

  alias CiBookTracker.Repo
  alias Exqlite.Sqlite3

  @expected_tables ~w(books provider_settings reading_logs schema_migrations)

  @type error ::
          :not_readable
          | :not_sqlite
          | :integrity_check_failed
          | {:missing_tables, [String.t()]}
          | :incompatible_migrations

  @spec validate(String.t()) :: :ok | {:error, error()}
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
end
