defmodule CiBookTracker.DatabaseRestore.Migration do
  @moduledoc "Upgrades only a staged copy of an older backup before it can be restored."

  alias CiBookTracker.DatabaseValidation

  defmodule Repo do
    use Ecto.Repo, otp_app: :ci_book_tracker, adapter: Ecto.Adapters.SQLite3
  end

  def prepare(path) do
    with :ok <- DatabaseValidation.validate(path, allow_older?: true),
         :ok <- upgrade_if_needed(path) do
      DatabaseValidation.validate(path)
    end
  end

  @doc false
  def sources do
    CiBookTracker.Repo
    |> Ecto.Migrator.migrations_path()
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn path ->
      # These are trusted application migration files, never uploaded code.
      {:defmodule, _, [{:__aliases__, _, name}, _body]} =
        path |> File.read!() |> Code.string_to_quoted!()

      module = Module.concat(name)
      unless Code.ensure_loaded?(module), do: Code.require_file(path)
      {version, _name} = path |> Path.basename() |> Integer.parse()
      {version, module}
    end)
  end

  defp upgrade_if_needed(path) do
    case DatabaseValidation.validate(path) do
      :ok -> :ok
      {:error, _reason} -> migrate(path)
    end
  end

  defp migrate(path) do
    # A private repository avoids changing the live repository or application config.
    # Historical table rebuilds toggle connection-local SQLite PRAGMAs, so all
    # migration statements must use the same connection. Migration locking is
    # disabled because this copy is private and needs no second connection.
    with {:ok, pid} <-
           Repo.start_link(
             name: nil,
             database: path,
             pool_size: 1,
             journal_mode: :delete,
             pool: DBConnection.ConnectionPool
           ) do
      try do
        Ecto.Migrator.run(Repo, sources(), :up,
          dynamic_repo: pid,
          all: true,
          migration_lock: false,
          log: false
        )

        :ok
      rescue
        _error -> {:error, :migration_failed}
      after
        Supervisor.stop(pid)
      end
    end
  end
end
