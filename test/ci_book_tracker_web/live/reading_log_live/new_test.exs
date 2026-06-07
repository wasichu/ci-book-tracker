defmodule CiBookTrackerWeb.ReadingLogLive.NewTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "shows a mobile-first reading log form with Spanish as the default", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    assert has_element?(view, "#create-reading-log-page")
    assert has_element?(view, "#create-reading-log-form")
    assert has_element?(view, "label", "Name")
    assert has_element?(view, "label", "Language code")
    assert has_element?(view, "#reading_log_language_code[value='es']")
    assert has_element?(view, "label", "Word goal")
    assert has_element?(view, "#save-reading-log", "Create Reading Log")
  end

  test "requires a name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    html =
      view
      |> form("#create-reading-log-form",
        reading_log: %{name: " ", language_code: "es", word_goal: ""}
      )
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert Library.list_reading_logs!() == []
  end

  test "creates a reading log without a word goal and returns to the dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    result =
      view
      |> form("#create-reading-log-form",
        reading_log: %{name: "Spanish novels", language_code: "ES", word_goal: ""}
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result

    [reading_log] = Library.list_reading_logs!()
    assert reading_log.name == "Spanish novels"
    assert reading_log.language_code == "es"
    assert is_nil(reading_log.word_goal)

    {:ok, dashboard, html} = follow_redirect(result, conn)
    assert html =~ "Spanish novels is ready."
    assert has_element?(dashboard, "#dashboard", "Spanish novels")
  end

  test "creates a reading log with a word goal", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    result =
      view
      |> form("#create-reading-log-form",
        reading_log: %{name: "Spanish", language_code: "es", word_goal: "75000"}
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert [%{word_goal: 75_000}] = Library.list_reading_logs!()
  end

  test "redirects to the dashboard when a reading log already exists", %{conn: conn} do
    Library.create_reading_log!("Spanish", "es", 50_000)

    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/reading-logs/new")
  end
end
