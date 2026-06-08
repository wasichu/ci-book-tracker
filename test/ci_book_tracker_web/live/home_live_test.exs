defmodule CiBookTrackerWeb.HomeLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "shows the empty reading log selector", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#reading-log-selector")
    assert has_element?(view, "#empty-reading-logs", "No reading logs yet")
    assert has_element?(view, "#create-reading-log", "Create New Reading Log")
    assert has_element?(view, "#create-reading-log[href='/reading-logs/new']")
  end

  test "lists all reading logs with human-readable details", %{conn: conn} do
    french = Library.create_reading_log!("French novels", "fr", 100_000)
    spanish = Library.create_reading_log!("Spanish essays", "es", nil)

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#reading-log-#{french.id}", "French novels")
    assert has_element?(view, "#reading-log-#{french.id}", "French")
    assert has_element?(view, "#reading-log-#{french.id}", "(fr)")
    assert has_element?(view, "#reading-log-#{french.id}", "100 thousand words")
    assert has_element?(view, "#open-reading-log-#{french.id}", "Open")

    assert has_element?(
             view,
             "#edit-reading-log-#{french.id}[href='/reading-logs/#{french.id}/edit']",
             "Edit"
           )

    assert has_element?(view, "#delete-reading-log-#{french.id}", "Delete")

    assert has_element?(view, "#reading-log-#{spanish.id}", "Spanish essays")
    assert has_element?(view, "#reading-log-#{spanish.id}", "Spanish")
    assert has_element?(view, "#reading-log-#{spanish.id}", "No word goal set")
  end

  test "auto-open session preference navigates from root to the dashboard", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 50_000)
    conn = init_test_session(conn, %{"auto_open_reading_log_id" => reading_log.id})

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, ~p"/")
  end

  test "ignores a stale auto-open preference", %{conn: conn} do
    conn = init_test_session(conn, %{"auto_open_reading_log_id" => Ecto.UUID.generate()})

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#reading-log-selector")
  end

  test "requires confirmation before deleting a reading log", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish novels", "es", 50_000)

    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "#delete-reading-log-confirmation")

    view
    |> element("#delete-reading-log-#{reading_log.id}")
    |> render_click()

    assert has_element?(
             view,
             "#delete-reading-log-confirmation",
             "Delete Spanish novels?"
           )

    assert has_element?(
             view,
             "#delete-reading-log-confirmation",
             "permanently deletes this reading log and every book in it"
           )

    assert has_element?(view, "#confirm-delete-reading-log", "Delete Reading Log")
    assert has_element?(view, "#cancel-delete-reading-log", "Cancel")

    view
    |> element("#cancel-delete-reading-log")
    |> render_click()

    refute has_element?(view, "#delete-reading-log-confirmation")
    assert Library.get_reading_log!(reading_log.id).name == "Spanish novels"
  end
end
