defmodule CiBookTrackerWeb.DashboardLiveTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "requires an active reading log", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/dashboard")
  end

  test "shows summaries and only books from the active log", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", 100_000)
    other_log = Library.create_reading_log!("Spanish", "es", 50_000)

    finished =
      Library.add_book!(reading_log.id, "Le Petit Prince", %{
        author: "Antoine de Saint-Exupery",
        estimated_words: 16_000,
        page_count: 96,
        difficulty_label: "Intermediate"
      })
      |> Library.finish_book!()

    other_book = Library.add_book!(other_log.id, "Invisible")
    conn = active_log(conn, reading_log)

    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard", "French")
    assert has_element?(view, "#dashboard", "100 thousand words")
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#words-completed", "16,000")
    assert has_element?(view, "#goal-progress", "16%")
    assert has_element?(view, "#books-finished #book-#{finished.id}", "Le Petit Prince")
    refute has_element?(view, "#book-#{other_book.id}")
    assert has_element?(view, "#switch-reading-log", "Switch Log")
    assert html =~ "Antoine de Saint-Exupery"
    assert html =~ "Intermediate"
    assert html =~ "96 pages"
  end

  test "shows empty status groups and no goal progress when goal is unset", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = active_log(conn, reading_log)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard", "Build your reading habit one book at a time.")
    refute has_element?(view, "#goal-progress")

    for status <- ~w(in_progress want_to_read finished abandoned) do
      assert has_element?(view, "#books-#{status}", "No books here yet.")
    end
  end

  test "shows the status controls appropriate for each book", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 100_000)
    want_to_read = Library.add_book!(reading_log.id, "Want")
    in_progress = reading_log.id |> Library.add_book!("Reading") |> Library.start_book!()
    finished = reading_log.id |> Library.add_book!("Done") |> Library.finish_book!()
    abandoned = reading_log.id |> Library.add_book!("Paused") |> Library.abandon_book!()
    conn = active_log(conn, reading_log)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#book-#{want_to_read.id}-start", "Start")
    assert has_element?(view, "#book-#{want_to_read.id}-finish", "Finish")
    assert has_element?(view, "#book-#{in_progress.id}-finish", "Finish")
    assert has_element?(view, "#book-#{in_progress.id}-abandon", "Abandon")
    assert has_element?(view, "#book-#{finished.id}-reopen", "Reopen")
    assert has_element?(view, "#book-#{abandoned.id}-reopen", "Reopen")
  end

  test "updates book status and summaries without leaving the page", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", 100_000)
    book = Library.add_book!(reading_log.id, "Hola", %{estimated_words: 20_000})
    conn = active_log(conn, reading_log)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    view |> element("#book-#{book.id}-start") |> render_click()
    assert has_element?(view, "#books-in_progress #book-#{book.id}")

    view |> element("#book-#{book.id}-finish") |> render_click()
    assert has_element?(view, "#books-finished #book-#{book.id}")
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#words-completed", "20,000")
    assert has_element?(view, "#goal-progress", "20%")

    view |> element("#book-#{book.id}-reopen") |> render_click()
    view |> element("#book-#{book.id}-abandon") |> render_click()
    assert has_element?(view, "#books-abandoned #book-#{book.id}")
  end

  defp active_log(conn, reading_log) do
    init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
  end
end
