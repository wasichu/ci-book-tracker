defmodule CiBookTrackerWeb.ReadingLogSessionController do
  use CiBookTrackerWeb, :controller

  alias CiBookTracker.Library

  def open(conn, %{"id" => id} = params) do
    case Library.get_reading_log(id) do
      {:ok, reading_log} ->
        conn
        |> put_session(:active_reading_log_id, reading_log.id)
        |> update_auto_open(reading_log.id, params["auto_open"])
        |> put_flash(:info, "#{reading_log.name} is open.")
        |> redirect(to: ~p"/dashboard")

      {:error, _error} ->
        conn
        |> put_flash(:error, "That reading log could not be found.")
        |> redirect(to: ~p"/")
    end
  end

  def switch(conn, _params) do
    conn
    |> delete_session(:active_reading_log_id)
    |> delete_session(:auto_open_reading_log_id)
    |> put_flash(:info, "Choose a reading log to continue.")
    |> redirect(to: ~p"/")
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, reading_log} <- Library.get_reading_log(id),
         :ok <- Library.delete_reading_log(reading_log) do
      conn
      |> clear_session_if_selected(:active_reading_log_id, reading_log.id)
      |> clear_session_if_selected(:auto_open_reading_log_id, reading_log.id)
      |> put_flash(:info, "#{reading_log.name} and its books were deleted.")
      |> redirect(to: ~p"/")
    else
      {:error, _error} ->
        conn
        |> put_flash(:error, "That reading log could not be deleted.")
        |> redirect(to: ~p"/")
    end
  end

  defp update_auto_open(conn, reading_log_id, auto_open)
       when auto_open in ["true", "on", "1"] do
    put_session(conn, :auto_open_reading_log_id, reading_log_id)
  end

  defp update_auto_open(conn, _reading_log_id, _auto_open) do
    delete_session(conn, :auto_open_reading_log_id)
  end

  defp clear_session_if_selected(conn, key, reading_log_id) do
    if get_session(conn, key) == reading_log_id do
      delete_session(conn, key)
    else
      conn
    end
  end
end
