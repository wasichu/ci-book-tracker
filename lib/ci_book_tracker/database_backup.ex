defmodule CiBookTracker.DatabaseBackup do
  @moduledoc """
  Resolves the SQLite database currently configured for the application.
  """

  alias CiBookTracker.{AppData, Repo}

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
    "ci_book_tracker_backup_#{Date.to_iso8601(date)}.sqlite3"
  end
end
