defmodule CiBookTrackerWeb.BackupLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows database backup controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")

    assert has_element?(view, "#database-backup", "Database backup")

    assert has_element?(
             view,
             "#database-backup",
             "Download a copy of your local database for backup."
           )

    assert has_element?(
             view,
             "#export-database[href='/backup/database']",
             "Export Database"
           )
  end

  test "the global header links to settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")
    assert has_element?(view, "#settings-link[href='/settings']")
  end
end
