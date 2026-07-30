defmodule CiBookTrackerWeb.DatabaseExportController do
  use CiBookTrackerWeb, :controller

  alias CiBookTracker.DatabaseBackup

  def download(conn, _params) do
    send_backup(conn, DatabaseBackup.create_archive())
  end

  @doc false
  def send_backup(conn, result) do
    case result do
      {:ok, path} ->
        case File.read(path) do
          {:ok, contents} ->
            File.rm(path)

            send_download(conn, {:binary, contents},
              filename: DatabaseBackup.filename(),
              content_type: "application/zip"
            )

          {:error, _reason} ->
            File.rm(path)
            backup_not_found(conn)
        end

      {:error, :not_found} ->
        backup_not_found(conn)
    end
  end

  defp backup_not_found(conn) do
    conn
    |> put_flash(:error, "The local database file could not be found.")
    |> redirect(to: ~p"/backup")
  end
end
