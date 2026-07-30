defmodule CiBookTrackerWeb.DatabaseExportControllerTest do
  use CiBookTrackerWeb.ConnCase

  alias CiBookTracker.DatabaseBackup
  alias CiBookTrackerWeb.DatabaseExportController

  test "downloads a portable ZIP backup", %{conn: conn} do
    conn = get(conn, ~p"/backup/database")

    body = response(conn, 200)
    assert get_resp_header(conn, "content-type") == ["application/zip"]
    assert {:ok, files} = :zip.extract(body, [:memory])
    assert List.keymember?(files, ~c"reading_log.db", 0)

    [content_disposition] = get_resp_header(conn, "content-disposition")
    assert content_disposition =~ "attachment"
    assert content_disposition =~ DatabaseBackup.filename()
  end

  test "redirects with a clear error when the database file is missing", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()
      |> DatabaseExportController.send_backup({:error, :not_found})

    assert redirected_to(conn) == "/backup"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "The local database file could not be found."
  end
end
