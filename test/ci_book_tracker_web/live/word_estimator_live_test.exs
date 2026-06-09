defmodule CiBookTrackerWeb.WordEstimatorLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  test "is available without an active reading log", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/word-estimator")

    assert has_element?(view, "#word-estimator-page", "Word Count Estimator")
    assert has_element?(view, "#word-estimator-form")
    assert has_element?(view, "#word-estimate-helper", "The sample is never saved.")
    assert has_element?(view, "#sample-word-count", "0")
    refute has_element?(view, "#apply-word-estimate")
  end

  test "estimates a whole book as the form changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/word-estimator")

    view
    |> form("#word-estimator-form",
      estimator: %{
        sample_text: "uno dos tres cuatro cinco seis",
        sample_units: "2",
        total_units: "100",
        unit_type: "pages"
      }
    )
    |> render_change()

    assert has_element?(view, "#sample-word-count", "6")
    assert has_element?(view, "#sample-estimated-words", "300")
  end

  test "shows estimator validation without persisting anything", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/word-estimator")

    view
    |> form("#word-estimator-form",
      estimator: %{
        sample_text: "uno dos tres",
        sample_units: "10",
        total_units: "5",
        unit_type: "pages"
      }
    )
    |> render_change()

    assert has_element?(
             view,
             "#word-estimate-error",
             "Total unit count must be at least the sample unit count."
           )
  end

  test "the global header links to the estimator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/word-estimator")
    assert has_element?(view, "#word-estimator-link[href='/word-estimator']")
  end
end
