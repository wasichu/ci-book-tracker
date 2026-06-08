defmodule CiBookTrackerWeb.DatabaseExportControllerTest do
  use CiBookTrackerWeb.ConnCase

  alias CiBookTracker.DatabaseBackup
  alias CiBookTrackerWeb.DatabaseExportController

  test "downloads the configured SQLite database", %{conn: conn} do
    conn = get(conn, ~p"/backup/database")

    assert response(conn, 200) =~ "SQLite format 3"
    assert get_resp_header(conn, "content-type") == ["application/vnd.sqlite3"]

    [content_disposition] = get_resp_header(conn, "content-disposition")
    assert content_disposition =~ "attachment"
    assert content_disposition =~ DatabaseBackup.filename()
  end

  test "redirects with a clear error when the database file is missing", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> DatabaseExportController.send_database({:error, :not_found})

    assert redirected_to(conn) == "/backup"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "The local database file could not be found."
  end
end
