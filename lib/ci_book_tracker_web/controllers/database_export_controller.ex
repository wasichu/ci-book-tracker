defmodule CiBookTrackerWeb.DatabaseExportController do
  use CiBookTrackerWeb, :controller

  alias CiBookTracker.DatabaseBackup

  def download(conn, _params) do
    send_database(conn, DatabaseBackup.available_database())
  end

  @doc false
  def send_database(conn, result) do
    case result do
      {:ok, path} ->
        send_download(conn, {:file, path},
          filename: DatabaseBackup.filename(),
          content_type: "application/vnd.sqlite3"
        )

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "The local database file could not be found.")
        |> redirect(to: ~p"/backup")
    end
  end
end
