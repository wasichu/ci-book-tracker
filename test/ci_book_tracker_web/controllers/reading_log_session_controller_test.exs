defmodule CiBookTrackerWeb.ReadingLogSessionControllerTest do
  use CiBookTrackerWeb.ConnCase

  alias CiBookTracker.Library

  test "opening a log stores it as active and goes to its dashboard", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", 100_000)

    conn = get(conn, ~p"/reading-logs/#{reading_log.id}/open")

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :active_reading_log_id) == reading_log.id
    assert is_nil(get_session(conn, :auto_open_reading_log_id))
  end

  test "opening with auto-open stores the persistent preference", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 50_000)

    conn = get(conn, ~p"/reading-logs/#{reading_log.id}/open?auto_open=true")

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :active_reading_log_id) == reading_log.id
    assert get_session(conn, :auto_open_reading_log_id) == reading_log.id
  end

  test "switching clears session choices without deleting data", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 50_000)

    conn =
      conn
      |> init_test_session(%{
        "active_reading_log_id" => reading_log.id,
        "auto_open_reading_log_id" => reading_log.id
      })
      |> delete(~p"/reading-log-session")

    assert redirected_to(conn) == "/"
    assert is_nil(get_session(conn, :active_reading_log_id))
    assert is_nil(get_session(conn, :auto_open_reading_log_id))
    assert Library.get_reading_log!(reading_log.id).name == "Spanish"
  end

  test "deleting a log also deletes its books and clears matching session choices", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 50_000)
    book = Library.add_book!(reading_log.id, "La sombra del viento")

    conn =
      conn
      |> init_test_session(%{
        "active_reading_log_id" => reading_log.id,
        "auto_open_reading_log_id" => reading_log.id
      })
      |> delete(~p"/reading-logs/#{reading_log.id}")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
             "Spanish and its books were deleted."

    assert is_nil(get_session(conn, :active_reading_log_id))
    assert is_nil(get_session(conn, :auto_open_reading_log_id))
    assert {:error, _error} = Library.get_reading_log(reading_log.id)
    assert Library.list_books!(query: [filter: [id: book.id]]) == []
  end

  test "deleting another log preserves the current session choices", %{conn: conn} do
    active_log = Library.create_reading_log!("French", "fr", 100_000)
    deleted_log = Library.create_reading_log!("Spanish", "es", 50_000)

    conn =
      conn
      |> init_test_session(%{
        "active_reading_log_id" => active_log.id,
        "auto_open_reading_log_id" => active_log.id
      })
      |> delete(~p"/reading-logs/#{deleted_log.id}")

    assert get_session(conn, :active_reading_log_id) == active_log.id
    assert get_session(conn, :auto_open_reading_log_id) == active_log.id
    assert Library.get_reading_log!(active_log.id).name == "French"
    assert {:error, _error} = Library.get_reading_log(deleted_log.id)
  end
end
