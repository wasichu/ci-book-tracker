defmodule CiBookTracker.DatabaseRestore.Runtime do
  @moduledoc "Stops and restarts the application repository around a database replacement."

  def prepare(false), do: {:ok, false}

  def prepare(true) do
    if Process.whereis(CiBookTracker.Repo) do
      with {:ok, _result} <-
             Ecto.Adapters.SQL.query(CiBookTracker.Repo, "PRAGMA wal_checkpoint(TRUNCATE)", []),
           :ok <- Supervisor.terminate_child(CiBookTracker.Supervisor, CiBookTracker.Repo) do
        {:ok, true}
      end
    else
      {:ok, false}
    end
  end

  def restart do
    case Supervisor.restart_child(CiBookTracker.Supervisor, CiBookTracker.Repo) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, :running} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
