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

  test "shows a recoverable message when creating an archive fails", %{conn: conn} do
    conn = conn |> init_test_session(%{}) |> fetch_flash()
    conn = DatabaseExportController.send_backup(conn, {:error, :snapshot_failed})
    assert redirected_to(conn) == "/backup"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "We couldn't create a backup. Please try again."
  end

  test "explains the shared size limit when export is too large", %{conn: conn} do
    conn = conn |> init_test_session(%{}) |> fetch_flash()
    conn = DatabaseExportController.send_backup(conn, {:error, :backup_too_large})

    assert redirected_to(conn) == "/backup"
    message = Phoenix.Flash.get(conn.assigns.flash, :error)
    assert message =~ "250 MB"
    assert message =~ "ZIP file or its expanded contents"
    assert message =~ "your library has not changed"
  end
end
