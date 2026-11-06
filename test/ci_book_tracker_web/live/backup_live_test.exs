defmodule CiBookTrackerWeb.BackupLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows database backup controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")

    assert has_element?(view, "#database-backup", "Backup and restore")

    assert has_element?(
             view,
             "#database-backup",
             "Keep a portable copy of your reading logs and cover art."
           )

    assert has_element?(
             view,
             "#export-database[href='/backup/database'][download]",
             "Export backup"
           )
  end

  test "the global header links to settings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")
    assert has_element?(view, "#settings-link[href='/settings']")
  end

  test "backup import opens the upload and validation flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/backup")

    assert has_element?(view, "#backup-restore-panel[hidden]")
    view |> element("#backup-tab-restore") |> render_click()
    refute has_element?(view, "#backup-restore-panel[hidden]")
    assert has_element?(view, "#backup-export-panel[hidden]")

    assert has_element?(view, "#import-backup", "Choose a backup")
    assert has_element?(view, "#database-backup", "Restoring replaces your current data.")
    assert has_element?(view, "#restore-warning", "You can restore that copy later.")

    assert has_element?(
             view,
             "#restore-backup-directory",
             CiBookTracker.DatabaseRestore.backup_directory()
           )

    {:ok, restore_view, _html} =
      view |> element("#import-backup") |> render_click() |> follow_redirect(conn)

    assert has_element?(restore_view, "#database-restore-form")
    refute has_element?(restore_view, "#validate-database")
    refute has_element?(restore_view, "#restore-confirmation")
  end
end
