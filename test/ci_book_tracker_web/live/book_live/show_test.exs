defmodule CiBookTrackerWeb.BookLive.ShowTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookMetadata.OpenLibrary

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
        page_count: 108,
        estimated_words: 82_500,
        difficulty_label: "B1",
        notes: "Read aloud."
      })

    {:ok, view, _html} = live(activate(conn, reading_log), ~p"/books/#{book.id}")

    assert has_element?(view, "#book-detail", "Le Petit Prince")
    assert has_element?(view, "#book-detail", "Antoine de Saint-Exupery")
    assert has_element?(view, "#book-details", "108")
    assert has_element?(view, "#book-details", "82.5 thousand")
    assert has_element?(view, "#book-details", "Not set")
    assert has_element?(view, "#book-notes", "Read aloud.")
    assert has_element?(view, "#back-to-dashboard")
    assert has_element?(view, "#edit-book")

    assert has_element?(
             view,
             "#find-metadata[href='/books/#{book.id}/edit?metadata=refresh']",
             "Refresh Metadata"
           )

    assert has_element?(view, "#book-detail-cover .hero-book-open")
    refute has_element?(view, "#book-detail-cover img")
  end

  test "reviews and applies refreshed metadata without overwriting saved book data", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    book =
      Library.add_book!(reading_log.id, "My Saved Title", %{
        author: "My Saved Author",
        notes: "Keep these notes.",
        status: :in_progress,
        started_on: ~D[2026-05-10]
      })

    conn = activate(conn, reading_log)
    {:ok, view, _html} = live(conn, ~p"/books/#{book.id}/edit?metadata=refresh")

    assert has_element?(view, "#metadata-search")
    assert has_element?(view, "#metadata-search", "Refresh Metadata")

    assert has_element?(
             view,
             "#metadata_query[value='My Saved Title My Saved Author']"
           )

    Req.Test.allow(OpenLibrary, self(), view.pid)

    Req.Test.stub(OpenLibrary, fn conn ->
      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL99W",
            "title" => "Provider Title",
            "author_name" => ["Provider Author"],
            "number_of_pages_median" => 160,
            "cover_i" => 999
          }
        ]
      })
    end)

    view
    |> form("#metadata-search-form",
      metadata: %{provider: "open_library", query: "My Saved Title My Saved Author"}
    )
    |> render_submit()

    view
    |> element("button[phx-click='select_metadata']")
    |> render_click()

    assert has_element?(view, "#metadata-review", "Provider Title")
    assert has_element?(view, "#metadata-review", "Title, author, notes")
    assert has_element?(view, "#book_title[value='My Saved Title']")
    assert has_element?(view, "#book_author[value='My Saved Author']")
    assert has_element?(view, "#book_page_count[value='']")

    view |> element("#apply-metadata") |> render_click()

    refute has_element?(view, "#metadata-review")
    assert has_element?(view, "#metadata-message", "then save the book")
    assert has_element?(view, "#book_title[value='My Saved Title']")
    assert has_element?(view, "#book_author[value='My Saved Author']")
    assert has_element?(view, "#book_page_count[value='160']")
    assert has_element?(view, "#book_estimated_words[value='40000']")
    assert has_element?(view, "input[name='book[cover_provider]'][value='open_library']")
    assert has_element?(view, "input[name='book[cover_id]'][value='999']")

    result = view |> form("#edit-book-form") |> render_submit()
    assert {:error, {:live_redirect, %{to: path}}} = result
    assert path == "/books/#{book.id}"

    updated = Library.get_book!(book.id)
    assert updated.title == "My Saved Title"
    assert updated.author == "My Saved Author"
    assert updated.notes == "Keep these notes."
    assert updated.status == :in_progress
    assert updated.started_on == ~D[2026-05-10]
    assert updated.finished_on == nil
    assert updated.page_count == 160
    assert updated.estimated_words == 40_000
    assert updated.cover_provider == "open_library"
    assert updated.cover_id == 999
  end

  test "refreshes only the cover when requested", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    book =
      Library.add_book!(reading_log.id, "My Saved Title", %{
        author: "My Saved Author",
        page_count: 123,
        estimated_words: 30_750,
        cover_provider: "google_books",
        cover_url: "https://books.google.com/old-cover.jpg"
      })

    {:ok, view, _html} =
      live(activate(conn, reading_log), ~p"/books/#{book.id}/edit?metadata=refresh")

    Req.Test.allow(OpenLibrary, self(), view.pid)

    Req.Test.stub(OpenLibrary, fn conn ->
      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL99W",
            "title" => "Provider Title",
            "author_name" => ["Provider Author"],
            "number_of_pages_median" => 400,
            "cover_i" => 999
          }
        ]
      })
    end)

    view
    |> form("#metadata-search-form",
      metadata: %{provider: "open_library", query: "My Saved Title"}
    )
    |> render_submit()

    view
    |> element("button[phx-click='select_cover']")
    |> render_click()

    refute has_element?(view, "#metadata-review")

    assert has_element?(
             view,
             "button[form='edit-book-form'][id^='save-selected-cover-']",
             "Save Changes"
           )

    assert has_element?(view, "#book_title[value='My Saved Title']")
    assert has_element?(view, "#book_author[value='My Saved Author']")
    assert has_element?(view, "#book_page_count[value='123']")
    assert has_element?(view, "#book_estimated_words[value='30750']")
    assert has_element?(view, "input[name='book[cover_provider]'][value='open_library']")
    assert has_element?(view, "input[name='book[cover_id]'][value='999']")

    assert {:error, {:live_redirect, %{to: path}}} =
             view |> form("#edit-book-form") |> render_submit()

    assert path == "/books/#{book.id}"

    updated = Library.get_book!(book.id)
    assert updated.title == "My Saved Title"
    assert updated.author == "My Saved Author"
    assert updated.page_count == 123
    assert updated.estimated_words == 30_750
    assert updated.cover_provider == "open_library"
    assert updated.cover_id == 999
    assert updated.cover_url == "https://covers.openlibrary.org/b/id/999-M.jpg"
  end

  test "shows a medium Open Library cover on the detail page", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    book =
      Library.add_book!(reading_log.id, "Cien anos de soledad", %{
        cover_provider: "open_library",
        cover_id: 456,
        cover_url: "https://covers.openlibrary.org/b/id/456-M.jpg"
      })

    {:ok, view, _html} = live(activate(conn, reading_log), ~p"/books/#{book.id}")

    assert has_element?(
             view,
             "#book-detail-cover img[src='https://covers.openlibrary.org/b/id/456-M.jpg'][alt='Cover of Cien anos de soledad']"
           )
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
    refute has_element?(finished_view, "#book-status-actions")
    refute has_element?(finished_view, "#book-reopen")

    {:ok, abandoned_view, _html} = live(conn, ~p"/books/#{abandoned.id}")
    refute has_element?(abandoned_view, "#book-status-actions")
    refute has_element?(abandoned_view, "#book-reopen")
  end

  test "updates status without leaving the detail page", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)
    book = Library.add_book!(reading_log.id, "L'Etranger")
    {:ok, view, _html} = live(activate(conn, reading_log), ~p"/books/#{book.id}")

    view |> element("#book-finish") |> render_click()

    assert has_element?(view, "#book-detail", "Finished")
    refute has_element?(view, "#book-status-actions")
    refute has_element?(view, "#book-reopen")

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
    assert has_element?(detail, "#book-details", "1.5 million")

    updated = Library.get_book!(book.id)
    assert updated.author == "New author"
    assert updated.status == :in_progress
    assert updated.started_on == ~D[2026-06-01]
  end

  test "allows total words to be edited when page count is present", %{conn: conn} do
    reading_log = Library.create_reading_log!("French", "fr", nil)

    book =
      Library.add_book!(reading_log.id, "Custom estimate", %{
        page_count: 200,
        estimated_words: 50_000
      })

    conn = activate(conn, reading_log)
    {:ok, view, _html} = live(conn, ~p"/books/#{book.id}/edit")

    assert has_element?(view, "#book_page_count[value='200']")
    assert has_element?(view, "#book_estimated_words[type='number'][value='50000']")
    refute has_element?(view, "#calculated-estimated-words")

    result =
      view
      |> form("#edit-book-form",
        book: %{page_count: "200", estimated_words: "42000"}
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: path}}} = result
    assert path == "/books/#{book.id}"

    updated = Library.get_book!(book.id)
    assert updated.page_count == 200
    assert updated.estimated_words == 42_000
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
