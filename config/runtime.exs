import Config

if System.get_env("PHX_SERVER") in ["true", "1"] do
  config :ci_book_tracker, CiBookTrackerWeb.Endpoint, server: true
end

if config_env() == :prod do
  data_directory =
    System.get_env("CI_BOOK_TRACKER_DATA_DIR") || CiBookTracker.AppData.default_directory()

  port = String.to_integer(System.get_env("PORT") || "4000")
  host = System.get_env("PHX_HOST") || "localhost"

  config :ci_book_tracker,
    app_data_directory: data_directory,
    migrate_on_start: true

  config :ci_book_tracker, CiBookTrackerWeb.Endpoint,
    server: System.get_env("PHX_SERVER") not in ["false", "0"],
    url: [host: host, port: port, scheme: "http"],
    http: [ip: {127, 0, 0, 1}, port: port],
    secret_key_base: CiBookTracker.LocalRuntime.secret_key_base(data_directory)

  config :ci_book_tracker, CiBookTracker.Repo,
    database: System.get_env("DATABASE_PATH") || :app_data,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
