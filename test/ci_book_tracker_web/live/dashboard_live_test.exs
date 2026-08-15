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
    assert has_element?(view, "#word-goal-card", "Goal")
    assert has_element?(view, "#word-goal-card", "100 thousand words")
    refute has_element?(view, "#word-goal-card", "100,000")
    refute render(view) =~ "Your goal is"
    assert has_element?(view, "#summary-books-finished", "1")
    assert has_element?(view, "#words-completed", "16,000")
    assert has_element?(view, "#goal-progress", "16%")
    assert has_element?(view, "#books-finished #book-#{finished.id}", "Le Petit Prince")

    {header_position, _length} = :binary.match(html, ~s(id="summary-cards"))
    {word_goal_position, _length} = :binary.match(html, ~s(id="word-goal-card"))
    {finished_summary_position, _length} = :binary.match(html, ~s(id="summary-books-finished"))

    assert header_position < word_goal_position
    assert word_goal_position < finished_summary_position

    assert has_element?(
             view,
             "#book-#{finished.id}-edit[href='/books/#{finished.id}/edit']",
             "Edit"
           )

    refute has_element?(view, "#book-#{other_book.id}")
    assert has_element?(view, "#switch-reading-log", "Switch Log")

    assert has_element?(
             view,
             "#dashboard-export-database[href='/backup/database']",
             "Export Backup"
           )

    assert has_element?(
             view,
             "#edit-reading-log[href='/reading-logs/#{reading_log.id}/edit?from=dashboard']",
             "Log Settings"
           )

    assert html =~ "Antoine de Saint-Exupery"
    assert html =~ "Intermediate"
    assert html =~ "96 pages"
  end

  test "shows empty status groups and no goal progress when goal is unset", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = active_log(conn, reading_log)

    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#dashboard", "Build your reading habit one book at a time.")
    refute has_element?(view, "#word-goal-card")
    refute has_element?(view, "#goal-progress")
    refute has_element?(view, "#summary-progress-volume")

    for status <- ~w(in_progress want_to_read finished abandoned) do
      assert has_element?(view, "#books-#{status}", "No books here yet.")
    end
  end

  test "shows small covers and placeholders without changing card layout", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    covered =
      reading_log.id
      |> Library.add_book!("Covered book")
      |> put_legacy_cover(%{
        cover_provider: "open_library",
        cover_id: 456,
        cover_url: "https://covers.openlibrary.org/b/id/456-M.jpg"
      })

    uncovered = Library.add_book!(reading_log.id, "Manual book")

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    assert has_element?(
             view,
             "#book-#{covered.id}-cover img[src='https://covers.openlibrary.org/b/id/456-S.jpg'][alt='Cover of Covered book']"
           )

    assert has_element?(view, "#book-#{uncovered.id}-cover .hero-book-open")
    refute has_element?(view, "#book-#{uncovered.id}-cover img")
  end

  test "orders completed words after finished books and prefers words in progress", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    reading_log.id
    |> Library.add_book!("First active book", %{page_count: 120, estimated_words: 30_000})
    |> Library.start_book!()

    reading_log.id
    |> Library.add_book!("Second active book", %{page_count: 80, estimated_words: 20_000})
    |> Library.start_book!()

    conn = active_log(conn, reading_log)
    {:ok, view, html} = live(conn, ~p"/dashboard")

    assert has_element?(
             view,
             "#summary-progress-volume",
             "Words in progress"
           )

    assert has_element?(view, "#summary-progress-volume", "50,000")
    refute has_element?(view, "#summary-progress-volume", "Pages in progress")

    {finished_position, _length} = :binary.match(html, ~s(id="summary-books-finished"))
    {words_position, _length} = :binary.match(html, ~s(id="words-completed"))
    {in_progress_position, _length} = :binary.match(html, ~s(id="summary-books-in-progress"))

    assert finished_position < words_position
    assert words_position < in_progress_position
  end

  test "falls back to pages when active books do not have word estimates", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    reading_log.id
    |> Library.add_book!("First active book", %{page_count: 120})
    |> Library.start_book!()

    reading_log.id
    |> Library.add_book!("Second active book", %{page_count: 80})
    |> Library.start_book!()

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    assert has_element?(view, "#summary-progress-volume", "Pages in progress")
    assert has_element?(view, "#summary-progress-volume", "200")
  end

  test "notes when active books do not have word estimates or page counts", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    reading_log.id |> Library.add_book!("Active book") |> Library.start_book!()

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    assert has_element?(
             view,
             "#summary-progress-volume",
             "Reading volume"
           )

    assert has_element?(view, "#summary-progress-volume", "Not set")
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

  test "searches books by title and author without a page reload", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    title_match =
      Library.add_book!(reading_log.id, "Cien Anos de Soledad", %{
        author: "Gabriel Garcia Marquez"
      })

    author_match =
      Library.add_book!(reading_log.id, "La Casa", %{author: "ISABEL ALLENDE"})

    hidden = Library.add_book!(reading_log.id, "El Principito", %{author: "Antoine"})

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    view
    |> form("#book-search-form", search: %{query: "soledad"})
    |> render_change()

    assert has_element?(view, "#book-#{title_match.id}")
    refute has_element?(view, "#book-#{author_match.id}")
    refute has_element?(view, "#book-#{hidden.id}")

    view
    |> form("#book-search-form", search: %{query: "isabel"})
    |> render_change()

    assert has_element?(view, "#book-#{author_match.id}")
    refute has_element?(view, "#book-#{title_match.id}")
    refute has_element?(view, "#book-#{hidden.id}")
  end

  test "combines status filters with search", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    wanted = Library.add_book!(reading_log.id, "Spanish Stories")

    reading =
      reading_log.id
      |> Library.add_book!("More Spanish Stories")
      |> Library.start_book!()

    hidden = Library.add_book!(reading_log.id, "French Stories")

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    view
    |> form("#book-search-form", search: %{query: "spanish"})
    |> render_change()

    view
    |> element("#filter-in_progress")
    |> render_click()

    assert has_element?(view, "#filter-in_progress.bg-slate-950")
    assert has_element?(view, "#books-in_progress #book-#{reading.id}")
    refute has_element?(view, "#book-#{wanted.id}")
    refute has_element?(view, "#book-#{hidden.id}")
    refute has_element?(view, "#books-want_to_read")
  end

  test "filters by distinct difficulty values and combines with status", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    a1_wanted =
      Library.add_book!(reading_log.id, "A1 Starter", %{difficulty_label: "A1"})

    a1_reading =
      reading_log.id
      |> Library.add_book!("A1 Reader", %{difficulty_label: "A1"})
      |> Library.start_book!()

    b1_reading =
      reading_log.id
      |> Library.add_book!("B1 Reader", %{difficulty_label: "B1"})
      |> Library.start_book!()

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    assert has_element?(view, "[aria-label='Filter books by difficulty']")
    assert has_element?(view, "button[phx-value-difficulty='A1']", "A1")
    assert has_element?(view, "button[phx-value-difficulty='B1']", "B1")

    view
    |> element("button[phx-value-difficulty='A1']")
    |> render_click()

    assert has_element?(view, "#book-#{a1_wanted.id}")
    assert has_element?(view, "#book-#{a1_reading.id}")
    refute has_element?(view, "#book-#{b1_reading.id}")

    view |> element("#filter-in_progress") |> render_click()

    refute has_element?(view, "#book-#{a1_wanted.id}")
    assert has_element?(view, "#book-#{a1_reading.id}")
    refute has_element?(view, "#book-#{b1_reading.id}")
  end

  test "shows a friendly empty state when no books match", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    Library.add_book!(reading_log.id, "El Principito")

    {:ok, view, _html} = live(active_log(conn, reading_log), ~p"/dashboard")

    view
    |> form("#book-search-form", search: %{query: "missing"})
    |> render_change()

    assert has_element?(view, "#no-matching-books", "No books match this search.")
    refute has_element?(view, "#books-want_to_read")
  end

  defp active_log(conn, reading_log) do
    init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
  end

  defp put_legacy_cover(book, attributes) do
    changeset = Ash.Changeset.for_update(book, :edit)

    attributes
    |> Enum.reduce(changeset, fn {attribute, value}, changeset ->
      Ash.Changeset.force_change_attribute(changeset, attribute, value)
    end)
    |> Ash.update!()
  end
end
