defmodule CiBookTrackerWeb.DatabaseRestoreLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.DatabaseBackup

  test "settings links to the destructive restore flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(
             view,
             "#settings-restore-database[href='/settings/restore']",
             "Restore Backup"
           )
  end

  test "shows restore safety guidance before a file is selected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    assert has_element?(view, "#database-restore-page", "Restore backup")
    assert has_element?(view, "#restore-upload", "Export your current database")
    assert has_element?(view, "#restore-upload a[href='/backup/database']")
    refute has_element?(view, "#restore-confirmation")
  end

  test "rejects a file that is not a SQLite database", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    upload =
      file_input(view, "#database-restore-form", :database, [
        %{name: "fake.sqlite3", content: "not a database", type: "application/vnd.sqlite3"}
      ])

    assert render_upload(upload, "fake.sqlite3") =~ "100%"
    view |> form("#database-restore-form") |> render_submit()

    assert has_element?(view, "#restore-upload", "not a readable SQLite database")
    refute has_element?(view, "#restore-confirmation")
  end

  test "validates an exported database and shows confirmation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/restore")
    {:ok, archive_path} = DatabaseBackup.create_archive()
    content = File.read!(archive_path)
    File.rm!(archive_path)

    upload =
      file_input(view, "#database-restore-form", :database, [
        %{
          name: "backup.zip",
          content: content,
          type: "application/zip"
        }
      ])

    assert render_upload(upload, "backup.zip") =~ "100%"
    view |> form("#database-restore-form") |> render_submit()

    assert has_element?(view, "#restore-confirmation", "Backup validated")

    assert has_element?(
             view,
             "#restore-confirmation",
             "This will replace your current reading logs, books, settings, metadata provider configuration, and locally stored cover art."
           )

    assert has_element?(view, "#cancel-restore", "Cancel")
    assert has_element?(view, "#confirm-restore", "Restore Backup")

    view |> element("#cancel-restore") |> render_click()
    refute has_element?(view, "#restore-confirmation")
  end
end
