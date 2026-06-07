defmodule CiBookTracker.Repo do
  use AshSqlite.Repo, otp_app: :ci_book_tracker

  @impl true
  def init(type, config) do
    database =
      case Keyword.fetch!(config, :database) do
        :app_data -> CiBookTracker.AppData.database_path()
        path -> path
      end

    database = CiBookTracker.AppData.ensure_database_directory!(database)

    super(type, Keyword.put(config, :database, database))
  end
end
