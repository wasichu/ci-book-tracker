defmodule CiBookTrackerWeb.DatabaseRestoreLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.DatabaseBackup
  alias CiBookTracker.Library

  test "front page links to the destructive restore flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#restore-backup[href='/settings/restore']",
             "Restore from Backup"
           )
  end

  test "shows restore safety guidance before a file is selected", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(reading_log.id, "A tracked book")
    conn = init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    assert has_element?(view, "#database-restore-page", "Restore backup")
    assert has_element?(view, "#restore-upload", "Export your current database")
    assert has_element?(view, "#restore-upload a[href='/backup/database']")
    refute has_element?(view, "#restore-confirmation")
  end

  test "hides the export warning when no reading log is open, even with saved books", %{
    conn: conn
  } do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(reading_log.id, "A tracked book")

    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    refute has_element?(view, "#restore-export-warning")
    assert has_element?(view, "#database-restore-form")
  end

  test "hides the export warning for an empty open log or stale selection", %{conn: conn} do
    empty_log = Library.create_reading_log!("French", "fr", nil)
    other_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(other_log.id, "A tracked book")

    for id <- [empty_log.id, Ecto.UUID.generate()] do
      selected_conn = init_test_session(conn, %{"active_reading_log_id" => id})
      {:ok, view, _html} = live(selected_conn, ~p"/settings/restore")
      refute has_element?(view, "#restore-export-warning")
    end
  end

  test "shows the export warning for an automatically opened log with books", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(reading_log.id, "A tracked book")
    conn = init_test_session(conn, %{"auto_open_reading_log_id" => reading_log.id})

    {:ok, view, _html} = live(conn, ~p"/settings/restore")
    assert has_element?(view, "#restore-export-warning")
  end

  test "rejects a file that is not a SQLite database", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/settings/restore")

    upload =
      file_input(view, "#database-restore-form", :database, [
        %{name: "fake.sqlite3", content: "not a database", type: "application/vnd.sqlite3"}
      ])

    render_upload(upload, "fake.sqlite3")

    assert has_element?(view, "#restore-upload", "not a readable SQLite database")
    refute has_element?(view, "#restore-confirmation")
  end

  test "automatically validates without confirmation when the open log is empty", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
    {:ok, view, _html} = live(conn, ~p"/settings/restore")
    {:ok, archive_path} = DatabaseBackup.create_archive()
    content = File.read!(archive_path)
    File.rm!(archive_path)

    upload =
      file_input(view, "#database-restore-form", :database, [
        %{name: "backup.zip", content: content, type: "application/zip"}
      ])

    render_upload(upload, "backup.zip")

    refute has_element?(view, "#restore-confirmation")
    refute has_element?(view, "#validate-database")
    assert has_element?(view, "#restore-ready", "backup.zip")
    assert has_element?(view, "#restore-backup-button", "Restore Backup")
    refute has_element?(view, "#restore-complete")

    view |> element("#restore-ready button", "Choose another file") |> render_click()
    assert has_element?(view, "#database-restore-form")
    refute has_element?(view, "#restore-ready")
  end

  test "automatically validates an exported database and shows confirmation for an open log with books",
       %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(reading_log.id, "A tracked book")
    conn = init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
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

    render_upload(upload, "backup.zip")

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
