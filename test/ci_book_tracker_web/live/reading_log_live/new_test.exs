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
    assert has_element?(view, "label", "Automatically open this log next time")
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

  test "creates a reading log and redirects through the session opener", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    result =
      view
      |> form("#create-reading-log-form",
        reading_log: %{
          name: "Spanish novels",
          language_code: "es",
          goal_amount: "",
          goal_unit: "thousand",
          auto_open: "false"
        }
      )
      |> render_submit()

    [reading_log] = Library.list_reading_logs!()
    assert {:error, {:redirect, %{to: path}}} = result
    assert path == "/reading-logs/#{reading_log.id}/open?auto_open=false"
    assert reading_log.name == "Spanish novels"
    assert reading_log.language_code == "es"
    assert is_nil(reading_log.word_goal)
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

    assert {:error, {:redirect, %{}}} = result
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

    assert {:error, {:redirect, %{}}} = result
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

  test "allows creating another reading log", %{conn: conn} do
    Library.create_reading_log!("Spanish", "es", 50_000)

    {:ok, view, _html} = live(conn, ~p"/reading-logs/new")

    view
    |> form("#create-reading-log-form",
      reading_log: %{
        name: "French",
        language_code: "fr",
        goal_amount: "",
        goal_unit: "words",
        auto_open: "true"
      }
    )
    |> render_submit()

    assert Enum.map(Library.list_reading_logs!(), & &1.name) |> Enum.sort() ==
             ["French", "Spanish"]
  end

  test "edits an existing reading log and returns to the selector", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 500_000)
    book = Library.add_book!(reading_log.id, "El Principito")

    {:ok, view, _html} = live(conn, ~p"/reading-logs/#{reading_log.id}/edit")

    assert has_element?(view, "#edit-reading-log-page", "Edit reading log")
    assert has_element?(view, "#reading_log_name[value='Spanish']")
    assert has_element?(view, "#reading_log_language_code option[value='es'][selected]")
    assert has_element?(view, "#reading_log_goal_amount[value='500']")
    assert has_element?(view, "#reading_log_goal_unit option[value='thousand'][selected]")
    assert has_element?(view, "#save-reading-log", "Save Changes")
    refute has_element?(view, "label", "Automatically open this log next time")

    result =
      view
      |> form("#edit-reading-log-form",
        reading_log: %{
          name: "Spanish novels",
          language_code: "es",
          goal_amount: "1",
          goal_unit: "million"
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result

    updated = Library.get_reading_log!(reading_log.id)
    assert updated.id == reading_log.id
    assert updated.name == "Spanish novels"
    assert updated.word_goal == 1_000_000
    assert Library.get_book!(book.id).reading_log_id == reading_log.id
  end

  test "returns an edited active log to the dashboard", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", 1_500_000)
    conn = init_test_session(conn, %{"active_reading_log_id" => reading_log.id})

    {:ok, view, _html} =
      live(conn, ~p"/reading-logs/#{reading_log.id}/edit?from=dashboard")

    assert has_element?(view, "#reading_log_goal_amount[value='1.5']")
    assert has_element?(view, "#reading_log_goal_unit option[value='million'][selected]")

    result =
      view
      |> form("#edit-reading-log-form",
        reading_log: %{
          name: "French literature",
          language_code: "fr",
          goal_amount: "",
          goal_unit: "thousand"
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = result
    assert Library.get_reading_log!(reading_log.id).word_goal == nil
  end

  test "requires a name when editing a reading log", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    {:ok, view, _html} = live(conn, ~p"/reading-logs/#{reading_log.id}/edit")

    html =
      view
      |> form("#edit-reading-log-form",
        reading_log: %{name: " ", language_code: "es", goal_amount: ""}
      )
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert Library.get_reading_log!(reading_log.id).name == "Spanish"
  end
end
