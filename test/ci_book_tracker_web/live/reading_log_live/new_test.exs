defmodule CiBookTrackerWeb.ReadingLogLive.NewTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "shows a mobile-first reading log form with Spanish as the default", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    assert has_element?(view, "#create-reading-log-page")
    assert has_element?(view, "#create-reading-log-form")
    assert has_element?(view, "label", "Name")
    assert has_element?(view, "label", "Language")
    assert has_element?(view, "#reading_log_language_code option[value='es']", "Spanish")
    assert has_element?(view, "#reading_log_language_code option[value='fr']", "French")
    assert has_element?(view, "#reading_log_language_code option[selected][value='es']")
    assert has_element?(view, "legend", "Word goal")
    assert has_element?(view, "label", "Goal amount")
    assert has_element?(view, "label", "Unit")
    assert has_element?(view, "#reading_log_goal_unit option[value='million']", "Million words")
    assert has_element?(view, "#save-reading-log", "Create Reading Log")
  end

  test "requires a name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    html =
      view
      |> form("#create-reading-log-form",
        reading_log: %{
          name: " ",
          language_code: "es",
          goal_amount: "",
          goal_unit: "thousand"
        }
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
        reading_log: %{
          name: "Spanish novels",
          language_code: "es",
          goal_amount: "",
          goal_unit: "thousand"
        }
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

  test "converts a thousand-word goal to the stored integer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    result =
      view
      |> form("#create-reading-log-form",
        reading_log: %{
          name: "Spanish",
          language_code: "es",
          goal_amount: "500",
          goal_unit: "thousand"
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert [%{word_goal: 500_000}] = Library.list_reading_logs!()
  end

  test "converts a decimal million-word goal to the stored integer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    result =
      view
      |> form("#create-reading-log-form",
        reading_log: %{
          name: "French",
          language_code: "fr",
          goal_amount: "1.5",
          goal_unit: "million"
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result
    assert [%{language_code: "fr", word_goal: 1_500_000}] = Library.list_reading_logs!()
  end

  test "shows an error for an invalid goal amount", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    html =
      view
      |> form("#create-reading-log-form",
        reading_log: %{
          name: "Spanish",
          language_code: "es",
          goal_amount: "-2",
          goal_unit: "million"
        }
      )
      |> render_submit()

    assert html =~ "must be a positive number"
    assert Library.list_reading_logs!() == []
  end

  test "redirects to the dashboard when a reading log already exists", %{conn: conn} do
    Library.create_reading_log!("Spanish", "es", 50_000)

    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/reading-logs/new")
  end
end
