defmodule CiBookTrackerWeb.HomeLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "shows a welcome screen and create reading log action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#welcome")
    assert has_element?(view, "#create-reading-log", "Create Reading Log")
    refute has_element?(view, "#dashboard")

    view |> element("#create-reading-log") |> render_click()
    assert render(view) =~ "Reading log setup is the next feature."
  end

  test "shows dashboard summaries and books grouped by status", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", 100_000)

    finished =
      Library.add_book!(reading_log.id, "Le Petit Prince", %{
        author: "Antoine de Saint-Exupery",
        estimated_words: 16_000,
        page_count: 96,
        difficulty_label: "Intermediate"
      })
      |> Library.finish_book!()

    in_progress =
      reading_log.id
      |> Library.add_book!("L'Etranger", %{estimated_words: 31_000})
      |> Library.start_book!()

    want_to_read = Library.add_book!(reading_log.id, "No et moi")

    abandoned =
      reading_log.id
      |> Library.add_book!("Madame Bovary")
      |> Library.abandon_book!()

    {:ok, view, html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard")
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#summary-books-in-progress", "1")
    assert has_element?(view, "#words-completed", "16,000")
    assert has_element?(view, "#goal-progress", "16%")
    assert has_element?(view, "#add-book", "Add Book")

    assert has_element?(view, "#books-finished #book-#{finished.id}", "Le Petit Prince")
    assert has_element?(view, "#books-in_progress #book-#{in_progress.id}", "L'Etranger")
    assert has_element?(view, "#books-want_to_read #book-#{want_to_read.id}", "No et moi")
    assert has_element?(view, "#books-abandoned #book-#{abandoned.id}", "Madame Bovary")

    assert html =~ "Antoine de Saint-Exupery"
    assert html =~ "Intermediate"
    assert html =~ "96 pages"

    assert has_element?(view, "#add-book[href='/books/new']")
  end

  test "shows empty placeholders for status groups without books", %{conn: conn} do
    Library.create_reading_log!("Spanish", "es", 50_000)

    {:ok, view, _html} = live(conn, ~p"/")

    for status <- ~w(in_progress want_to_read finished abandoned) do
      assert has_element?(view, "#books-#{status}", "No books here yet.")
    end
  end
end
