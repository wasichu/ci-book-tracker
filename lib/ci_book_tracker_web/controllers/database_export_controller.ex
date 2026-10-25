defmodule CiBookTrackerWeb.DatabaseExportController do
  use CiBookTrackerWeb, :controller

  alias CiBookTracker.{BackupArchive, DatabaseBackup}

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

      {:error, :backup_too_large} ->
        conn
        |> put_flash(
          :error,
          "The backup exceeds the #{BackupArchive.limit_label()} limit for the ZIP file or its expanded contents. Export was cancelled; your library has not changed."
        )
        |> redirect(to: ~p"/backup")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "We couldn't create a backup. Please try again.")
        |> redirect(to: ~p"/backup")
    end
  end

  defp backup_not_found(conn) do
    conn
    |> put_flash(:error, "The local database file could not be found.")
    |> redirect(to: ~p"/backup")
  end
end
