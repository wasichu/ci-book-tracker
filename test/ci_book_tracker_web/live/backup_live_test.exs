defmodule CiBookTrackerWeb.BackupLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows database backup controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")

    assert has_element?(view, "#database-backup", "Portable backup")

    assert has_element?(
             view,
             "#database-backup",
             "Download a portable copy of your database and locally stored cover art."
           )

    assert has_element?(
             view,
             "#export-database[href='/backup/database']",
             "Export Backup"
           )
  end

  test "the global header links to settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")
    assert has_element?(view, "#settings-link[href='/settings']")
  end

  test "backup import opens the upload and validation flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")

    assert has_element?(view, "#import-backup", "Import / Restore Backup")
    assert has_element?(view, "#database-backup", "Restoring replaces your current data.")

    {:ok, restore_view, _html} =
      view |> element("#import-backup") |> render_click() |> follow_redirect(conn)

    assert has_element?(restore_view, "#database-restore-form")
    refute has_element?(restore_view, "#validate-database")
    refute has_element?(restore_view, "#restore-confirmation")
  end
end
