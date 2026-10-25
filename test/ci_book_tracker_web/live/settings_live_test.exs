defmodule CiBookTrackerWeb.SettingsLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Settings.MetadataProviders

  test "switches settings and provider panels", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/settings")
    assert has_element?(view, "#database-settings[hidden]")
    view |> element("#provider-tab-google_books") |> render_click()
    assert has_element?(view, "#open-library-settings[hidden]")
    refute has_element?(view, "#google-books-settings[hidden]")
    view |> element("#settings-tab-data") |> render_click()
    refute has_element?(view, "#database-settings[hidden]")
    assert has_element?(view, "#metadata-provider-settings[hidden]")
    view |> element("#settings-tab-providers") |> render_click()
    refute has_element?(view, "#google-books-settings[hidden]")
  end

  test "shows database, provider, and application settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(view, "#settings-page", "Settings")

    assert has_element?(
             view,
             "#database-settings",
             "Reading logs, books, settings, and cover images"
           )

    assert has_element?(view, "#settings-export-database[href='/backup/database']")
    refute has_element?(view, "#settings-restore-database")
    assert has_element?(view, "#open-library-settings", "Enabled")
    assert has_element?(view, "#google-books-settings", "Optional API key")
    assert has_element?(view, "#hardcover-settings", "API token")
    assert has_element?(view, "#application-settings", "0.2.0")
    refute has_element?(view, "#application-settings", "Environment")
  end

  test "About shows the SQLite engine version used by the running database", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")
    view |> element("#settings-tab-application") |> render_click()
    refute has_element?(view, "#application-settings[hidden]")
    assert has_element?(view, "#application-settings", "SQLite version")
    assert has_element?(view, "#application-settings", CiBookTracker.Repo.sqlite_version())
  end

  test "saves Google Books configuration", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    view
    |> form("#google-books-settings form",
      provider: %{
        name: "google_books",
        enabled: "false",
        credential: "google-key"
      }
    )
    |> render_submit()

    refute has_element?(view, "#flash-info")
    assert %{enabled: false, credential: "google-key"} = MetadataProviders.get(:google_books)
  end

  test "Hardcover stays disabled until a token is saved", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    view
    |> form("#hardcover-settings form",
      provider: %{name: "hardcover", enabled: "true", credential: ""}
    )
    |> render_submit()

    assert render(view) =~ "Hardcover remains disabled until an API token is provided."
    refute MetadataProviders.configured?(:hardcover)

    view
    |> form("#hardcover-settings form",
      provider: %{name: "hardcover", enabled: "true", credential: "hardcover-token"}
    )
    |> render_submit()

    refute has_element?(view, "#flash-info")
    assert MetadataProviders.configured?(:hardcover)
  end

  test "the global header links to settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")
    assert has_element?(view, "#settings-link[href='/settings']")
  end
end
