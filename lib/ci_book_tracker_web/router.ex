defmodule CiBookTrackerWeb.Router do
  use CiBookTrackerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CiBookTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CiBookTrackerWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/dashboard", DashboardLive, :index
    live "/backup", BackupLive, :index
    live "/settings", SettingsLive, :index
    live "/settings/restore", DatabaseRestoreLive, :index
    live "/word-estimator", WordEstimatorLive, :index
    live "/reading-logs/new", ReadingLogLive.New, :new
    live "/reading-logs/:id/edit", ReadingLogLive.New, :edit
    live "/books/new", BookLive.Form, :new
    live "/books/import", BookLive.Import, :new
    live "/books/:id/edit", BookLive.Form, :edit
    live "/books/:id", BookLive.Show, :show

    get "/covers/:filename", BookCoverController, :show
    get "/reading-logs/:id/open", ReadingLogSessionController, :open
    delete "/reading-logs/:id", ReadingLogSessionController, :delete
    delete "/reading-log-session", ReadingLogSessionController, :switch
    get "/backup/database", DatabaseExportController, :download
  end

  # Other scopes may use custom stacks.
  # scope "/api", CiBookTrackerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:ci_book_tracker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CiBookTrackerWeb.Telemetry
    end
  end
end
