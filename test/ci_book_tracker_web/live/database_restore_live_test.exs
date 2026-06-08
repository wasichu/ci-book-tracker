defmodule CiBookTrackerWeb.DatabaseRestoreLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.DatabaseBackup

  test "settings links to the destructive restore flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings")

    assert has_element?(
             view,
             "#settings-restore-database[href='/settings/restore']",
             "Restore Database"
           )
  end

  test "shows restore safety guidance before a file is selected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    assert has_element?(view, "#database-restore-page", "Restore database")
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
    content = File.read!(DatabaseBackup.database_path())

    upload =
      file_input(view, "#database-restore-form", :database, [
        %{
          name: "backup.sqlite3",
          content: content,
          type: "application/vnd.sqlite3"
        }
      ])

    assert render_upload(upload, "backup.sqlite3") =~ "100%"
    view |> form("#database-restore-form") |> render_submit()

    assert has_element?(view, "#restore-confirmation", "Database validated")

    assert has_element?(
             view,
             "#restore-confirmation",
             "This will replace your current reading logs, books, settings, and metadata provider configuration."
           )

    assert has_element?(view, "#cancel-restore", "Cancel")
    assert has_element?(view, "#confirm-restore", "Restore Database")

    view |> element("#cancel-restore") |> render_click()
    refute has_element?(view, "#restore-confirmation")
  end
end
