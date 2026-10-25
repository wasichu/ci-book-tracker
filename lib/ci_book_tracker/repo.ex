defmodule CiBookTracker.Repo do
  use AshSqlite.Repo, otp_app: :ci_book_tracker

  @spec sqlite_version() :: String.t()
  def sqlite_version do
    %{rows: [[version]]} = Ecto.Adapters.SQL.query!(__MODULE__, "SELECT sqlite_version()", [])
    version
  end

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
