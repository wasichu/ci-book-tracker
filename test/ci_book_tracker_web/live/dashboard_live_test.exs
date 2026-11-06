defmodule CiBookTrackerWeb.DashboardLiveTest do
  use CiBookTrackerWeb.ConnCase
  import Phoenix.LiveViewTest
  alias CiBookTracker.Library

  test "requires an active reading log", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/dashboard")
  end

  test "shows the compact summary and keeps other reading logs out of the library", %{conn: conn} do
    log = Library.create_reading_log!("French novels", "fr", 100_000)
    other = Library.create_reading_log!("Spanish", "es", 50_000)

    finished =
      Library.add_book!(log.id, "Le Petit Prince", %{
        estimated_words: 16_000,
        page_count: 96,
        difficulty_label: "B1"
      })
      |> Library.finish_book!()

    hidden = Library.add_book!(other.id, "Invisible")
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")

    assert has_element?(view, "#workspace-sidebar", "French novels")
    assert has_element?(view, "#dashboard", "French")
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#words-completed", "16,000")
    assert has_element?(view, "#goal-progress", "16%")
    assert has_element?(view, "#books-#{finished.id}", "Le Petit Prince")
    refute has_element?(view, "#books-#{hidden.id}")
    assert has_element?(view, "#inspector-book-title", "Le Petit Prince")
    assert has_element?(view, "#inspector-edit-book[href='/books/#{finished.id}/edit']")
  end

  test "shows a useful empty library rather than four empty status groups", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    assert has_element?(view, "#empty-library", "Your next chapter starts here.")
    assert has_element?(view, "#book-inspector", "Select a book")
    refute has_element?(view, "#goal-progress")
    assert has_element?(view, "#book-page-range", "0–0 of 0 books")
  end

  test "selects books and swaps details, notes and metadata in the inspector", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)

    first =
      Library.add_book!(log.id, "First", %{
        author: "A reader",
        notes: "Remember this passage",
        page_count: 205
      })

    second = Library.add_book!(log.id, "Second", %{author: "Another reader"})
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    view |> element("#select-book-#{first.id}") |> render_click()
    assert has_element?(view, "#select-book-#{first.id}[aria-pressed=true]")
    assert has_element?(view, "#inspector-book-title", "First")
    assert has_element?(view, "#book-inspector", "205")
    view |> element("#inspector-tab-notes") |> render_click()
    assert has_element?(view, "#inspector-notes", "Remember this passage")
    view |> element("#inspector-tab-metadata") |> render_click()

    assert has_element?(
             view,
             "#inspector-refresh-metadata[href='/books/#{first.id}/edit?metadata=refresh']"
           )

    view |> element("#select-book-#{second.id}") |> render_click()
    assert has_element?(view, "#inspector-book-title", "Second")
    assert has_element?(view, "#inspector-tab-details[aria-pressed=true]")
    refute has_element?(view, "#select-book-#{first.id}[aria-pressed=true]")
  end

  test "hides and reopens the inspector without navigating away", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)
    book = Library.add_book!(log.id, "Covered book")
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    view |> element("#close-book-inspector") |> render_click()
    refute has_element?(view, "#book-inspector")
    assert has_element?(view, "#dashboard.is-inspector-closed")
    view |> element("#select-book-#{book.id}") |> render_click()
    assert has_element?(view, "#book-inspector")
    view |> element("#toggle-book-inspector") |> render_click()
    refute has_element?(view, "#book-inspector")
  end

  test "ignores attempts to inspect or change a book from another log", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)
    other = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(other.id, "Private to the other log")
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard?book=#{book.id}")
    render_click(view, "select_book", %{"id" => book.id})
    refute has_element?(view, "#inspector-book-title")
    render_click(view, "update_status", %{"book_id" => book.id, "action" => "finish"})
    assert Library.get_book!(book.id).status == :want_to_read
  end

  test "pages the library and adapts the number of rows to available height", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)
    for index <- 1..9, do: Library.add_book!(log.id, "Book #{index}")
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")

    assert has_element?(view, "#book-list > [data-book-row]:nth-child(4)")
    refute has_element?(view, "#book-list > [data-book-row]:nth-child(5)")

    assert has_element?(view, "#book-page-range", "1–4 of 9 books")
    view |> element("#next-book-page") |> render_click()
    assert has_element?(view, "#book-page-range", "5–8 of 9 books")
    render_hook(view, "resize_books", %{"rows" => 2})
    assert has_element?(view, "#book-page-range", "5–6 of 9 books")
    view |> element("#previous-book-page") |> render_click()
    assert has_element?(view, "#book-page-range", "3–4 of 9 books")
    render_hook(view, "resize_books", %{"rows" => 1000})
    assert has_element?(view, "#book-page-range", "1–9 of 9 books")
  end

  test "a book query opens its page and inspector even when it is not on the first page", %{
    conn: conn
  } do
    log = Library.create_reading_log!("Spanish", "es", nil)
    target = Library.add_book!(log.id, "An older book")
    for index <- 1..7, do: Library.add_book!(log.id, "Newer #{index}")
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard?book=#{target.id}")
    assert has_element?(view, "#inspector-book-title", "An older book")
    assert has_element?(view, "#select-book-#{target.id}[aria-pressed=true]")
  end

  test "reading status actions update the book and summary in place", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", 100_000)
    book = Library.add_book!(log.id, "Hola", %{estimated_words: 20_000})
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    view |> element("#book-#{book.id}-start") |> render_click()
    assert Library.get_book!(book.id).status == :in_progress
    assert has_element?(view, "#summary-books-in-progress", "1")
    view |> element("#book-#{book.id}-finish") |> render_click()
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#words-completed", "20,000")
    assert has_element?(view, "#goal-progress", "20%")
    view |> element("#book-#{book.id}-reopen") |> render_click()
    view |> element("#book-#{book.id}-abandon") |> render_click()
    assert Library.get_book!(book.id).status == :abandoned
  end

  test "search, status and difficulty filters combine and reset pagination", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", nil)
    wanted = Library.add_book!(log.id, "Spanish Stories", %{difficulty_label: "A1"})

    reading =
      Library.add_book!(log.id, "More Spanish Stories", %{
        author: "ISABEL",
        difficulty_label: "A1"
      })
      |> Library.start_book!()

    hidden = Library.add_book!(log.id, "French Stories", %{difficulty_label: "B1"})
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    view |> form("#book-search-form", search: %{query: "spanish"}) |> render_change()
    assert has_element?(view, "#books-#{wanted.id}")
    assert has_element?(view, "#books-#{reading.id}")
    refute has_element?(view, "#books-#{hidden.id}")
    view |> element("#filter-in_progress") |> render_click()
    assert has_element?(view, "#filter-in_progress[aria-pressed=true]")
    refute has_element?(view, "#books-#{wanted.id}")
    view |> form("#difficulty-filter-form", %{"difficulty" => "A1"}) |> render_change()
    assert has_element?(view, "#books-#{reading.id}")
    view |> form("#book-search-form", search: %{query: "isabel"}) |> render_change()
    assert has_element?(view, "#books-#{reading.id}")
    view |> form("#book-search-form", search: %{query: "missing"}) |> render_change()
    assert has_element?(view, "#no-matching-books", "No books match this search.")
    refute has_element?(view, "#inspector-book-title")
  end

  test "opens and closes detailed progress in the central workspace", %{conn: conn} do
    log = Library.create_reading_log!("Spanish", "es", 100_000)
    Library.add_book!(log.id, "Done", %{estimated_words: 16_000}) |> Library.finish_book!()
    Library.add_book!(log.id, "Reading", %{estimated_words: 20_000}) |> Library.start_book!()
    {:ok, view, _} = live(active_log(conn, log), ~p"/dashboard")
    refute has_element?(view, "#reading-progress-panel")
    render_patch(view, ~p"/dashboard?view=progress")
    assert has_element?(view, "#word-goal-card", "100 thousand words")
    assert has_element?(view, "#summary-progress-volume", "20,000")
    assert has_element?(view, "#summary-progress-volume", "Words in progress")
    assert has_element?(view, "#dashboard-export-database[href='/backup/database']")
    render_patch(view, ~p"/dashboard")
    refute has_element?(view, "#reading-progress-panel")
  end

  defp active_log(conn, log), do: init_test_session(conn, %{"active_reading_log_id" => log.id})
end
