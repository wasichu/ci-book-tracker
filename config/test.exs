import Config

config :ci_book_tracker, CiBookTracker.Repo,
  database:
    Path.expand(
      "../ci_book_tracker_test#{System.get_env("MIX_TEST_PARTITION")}.db",
      __DIR__
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ci_book_tracker, CiBookTrackerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3AlXz58sz30mmMABymuU45GndHEG1mI7jYFd3oHlbw8BdrWijUEQQW2DzLB3w4vF",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
