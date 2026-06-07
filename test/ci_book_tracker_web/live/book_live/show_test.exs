defmodule CiBookTrackerWeb.BookLive.ShowTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "requires an active reading log", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(reading_log.id, "Le Petit Prince")

    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/books/#{book.id}")
  end

  test "does not show a book from another reading log", %{conn: conn} do
    active_log = Library.create_reading_log!("French", "fr", nil)
    other_log = Library.create_reading_log!("Spanish", "es", nil)
    book = Library.add_book!(other_log.id, "Invisible")
    conn = activate(conn, active_log)

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = live(conn, ~p"/books/#{book.id}")
  end

  test "shows book details with readable formatting and missing values", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)

    book =
      Library.add_book!(reading_log.id, "Le Petit Prince", %{
        author: "Antoine de Saint-Exupery",
        estimated_words: 82_500,
        difficulty_label: "B1",
        notes: "Read aloud."
      })

    {:ok, view, _html} = live(activate(conn, reading_log), ~p"/books/#{book.id}")

    assert has_element?(view, "#book-detail", "Le Petit Prince")
    assert has_element?(view, "#book-detail", "Antoine de Saint-Exupery")
    assert has_element?(view, "#book-details", "82.5 thousand words")
    assert has_element?(view, "#book-details", "Not set")
    assert has_element?(view, "#book-notes", "Read aloud.")
    assert has_element?(view, "#back-to-dashboard")
    assert has_element?(view, "#edit-book")
  end

  test "shows status actions appropriate to the current status", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    want = Library.add_book!(reading_log.id, "Want")
    reading = reading_log.id |> Library.add_book!("Reading") |> Library.start_book!()
    finished = reading_log.id |> Library.add_book!("Done") |> Library.finish_book!()
    abandoned = reading_log.id |> Library.add_book!("Paused") |> Library.abandon_book!()
    conn = activate(conn, reading_log)

    {:ok, want_view, _html} = live(conn, ~p"/books/#{want.id}")
    assert has_element?(want_view, "#book-start")
    assert has_element?(want_view, "#book-finish")
    assert has_element?(want_view, "#book-abandon")
    refute has_element?(want_view, "#book-reopen")

    {:ok, reading_view, _html} = live(conn, ~p"/books/#{reading.id}")
    assert has_element?(reading_view, "#book-finish")
    assert has_element?(reading_view, "#book-abandon")
    refute has_element?(reading_view, "#book-start")

    {:ok, finished_view, _html} = live(conn, ~p"/books/#{finished.id}")
    assert has_element?(finished_view, "#book-reopen")

    {:ok, abandoned_view, _html} = live(conn, ~p"/books/#{abandoned.id}")
    assert has_element?(abandoned_view, "#book-reopen")
  end

  test "updates status without leaving the detail page", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(reading_log.id, "L'Etranger")
    {:ok, view, _html} = live(activate(conn, reading_log), ~p"/books/#{book.id}")

    view |> element("#book-finish") |> render_click()

    assert has_element?(view, "#book-detail", "Finished")
    assert has_element?(view, "#book-reopen")

    updated = Library.get_book!(book.id)
    assert updated.status == :finished
    assert updated.started_on == Date.utc_today()
    assert updated.finished_on == Date.utc_today()
  end

  test "edits a book and returns to its detail page", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(reading_log.id, "Old title")
    conn = activate(conn, reading_log)

    {:ok, view, _html} = live(conn, ~p"/books/#{book.id}/edit")
    assert has_element?(view, "#edit-book-form")
    assert has_element?(view, "#book_title[value='Old title']")
    assert has_element?(view, "#save-book", "Save Changes")

    result =
      view
      |> form("#edit-book-form",
        book: %{
          title: "New title",
          author: "New author",
          page_count: "",
          estimated_words: "1500000",
          difficulty_label: "C1",
          status: "in_progress",
          started_on: "2026-06-01",
          finished_on: "",
          notes: "Updated notes"
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: path}}} = result
    assert path == "/books/#{book.id}"

    {:ok, detail, html} = follow_redirect(result, conn)
    assert html =~ "New title was updated."
    assert has_element?(detail, "#book-detail", "New title")
    assert has_element?(detail, "#book-details", "1.5 million words")

    updated = Library.get_book!(book.id)
    assert updated.author == "New author"
    assert updated.status == :in_progress
    assert updated.started_on == ~D[2026-06-01]
  end

  test "confirms deletion and returns to a refreshed dashboard", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)

    book =
      reading_log.id
      |> Library.add_book!("Finished book", %{estimated_words: 20_000})
      |> Library.finish_book!()

    conn = activate(conn, reading_log)
    {:ok, view, _html} = live(conn, ~p"/books/#{book.id}")

    refute has_element?(view, "#delete-book-confirmation")
    view |> element("#delete-book") |> render_click()
    assert has_element?(view, "#delete-book-confirmation", "Delete “Finished book”?")

    result = view |> element("#confirm-delete-book") |> render_click()
    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = result

    {:ok, dashboard, html} = follow_redirect(result, conn)
    assert html =~ "Finished book was deleted."
    assert has_element?(dashboard, "#summary-books-finished", "0")
    assert has_element?(dashboard, "#words-completed", "0")
    refute has_element?(dashboard, "#book-#{book.id}")
    assert {:error, _error} = Library.get_book(book.id)
  end

  test "dashboard book titles navigate to detail", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(reading_log.id, "Clickable")
    {:ok, dashboard, _html} = live(activate(conn, reading_log), ~p"/dashboard")

    assert has_element?(dashboard, "#book-#{book.id} a[href='/books/#{book.id}']", "Clickable")
  end

  defp activate(conn, reading_log) do
    init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
  end
end
