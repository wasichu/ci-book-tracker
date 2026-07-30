defmodule CiBookTrackerWeb.SettingsLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Settings.MetadataProviders

  test "shows database, provider, and application settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(view, "#settings-page", "Settings")

    assert has_element?(
             view,
             "#database-settings",
             "Reading logs, books, settings, and cover images"
           )

    assert has_element?(view, "#settings-export-database[href='/backup/database']")
    assert has_element?(view, "#settings-restore-database[href='/settings/restore']")
    assert has_element?(view, "#open-library-settings", "Enabled")
    assert has_element?(view, "#google-books-settings", "Optional API key")
    assert has_element?(view, "#hardcover-settings", "API token")
    assert has_element?(view, "#application-settings", "0.1.0")
    refute has_element?(view, "#application-settings", "Environment")
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

    assert render(view) =~ "Google Books settings saved."
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

    assert render(view) =~ "Hardcover settings saved."
    assert MetadataProviders.configured?(:hardcover)
  end

  test "the global header links to settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")
    assert has_element?(view, "#settings-link[href='/settings']")
  end
end
