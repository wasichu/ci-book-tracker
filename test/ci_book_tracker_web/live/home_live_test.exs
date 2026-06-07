defmodule CiBookTrackerWeb.HomeLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "shows the empty reading log state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#empty-reading-logs")
    assert render(view) =~ "Start with a language"
  end

  test "shows existing reading logs", %{conn: conn} do
    Library.create_reading_log!("French", "fr", 100_000)

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#reading-logs")
    assert render(view) =~ "French"
    refute has_element?(view, "#empty-reading-logs")
  end
end
