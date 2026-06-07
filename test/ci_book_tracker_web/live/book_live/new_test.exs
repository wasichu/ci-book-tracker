defmodule CiBookTrackerWeb.BookLive.NewTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "requires a reading log", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/books/new")
  end

  test "shows a phone-friendly add book form", %{conn: conn} do
    create_reading_log()

    {:ok, view, _html} = live(conn, ~p"/books/new")

    assert has_element?(view, "#add-book-page")
    assert has_element?(view, "#add-book-form")
    assert has_element?(view, "label", "Title")
    assert has_element?(view, "label", "Author")
    assert has_element?(view, "label", "Page count")
    assert has_element?(view, "label", "Estimated Total Words")
    refute has_element?(view, "#calculated-estimated-words")
    assert has_element?(view, "label", "Difficulty")
    assert has_element?(view, "label", "Reading status")
    assert has_element?(view, "#book_status option[value='want_to_read']", "Want to read")
    assert has_element?(view, "#book_status option[value='in_progress']", "In progress")
    assert has_element?(view, "#book_status option[value='finished']", "Finished")
    assert has_element?(view, "#book_status option[value='abandoned']", "Abandoned")
    assert has_element?(view, "#book_status option[value='want_to_read'][selected]")
    assert has_element?(view, "label", "Started on")
    assert has_element?(view, "label", "Finished on")
    assert render(view) =~ "Adding a book you&#39;ve already started or finished?"
    assert has_element?(view, "label", "Notes")
    assert has_element?(view, "#save-book", "Save Book")
  end

  test "shows a read-only formatted total calculated from page count", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: ""})
    |> render_change()

    assert has_element?(view, "#calculated-estimated-words", "30,000")
    assert has_element?(view, "#calculated-estimated-words", "Using 250 words per page")
    assert has_element?(view, "input[name='book[estimated_words]'][type='hidden'][value='30000']")
    refute has_element?(view, "#book_estimated_words[type='number']")
  end

  test "page count overrides a conflicting manual estimate", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: "27500"})
    |> render_change()

    assert has_element?(view, "#calculated-estimated-words", "30,000")
    assert has_element?(view, "input[name='book[estimated_words]'][value='30000']")
  end

  test "allows a manual total when page count is blank", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "", estimated_words: "27500"})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[type='number'][value='27500']")
    refute has_element?(view, "#calculated-estimated-words")
  end

  test "clears a calculated total when page count is removed", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: ""})
    |> render_change()

    view
    |> form("#add-book-form",
      book: %{
        page_count: "",
        estimated_words: "30000",
        estimated_words_mode: "calculated"
      }
    )
    |> render_change()

    assert has_element?(view, "#book_estimated_words[type='number'][value='']")
    refute has_element?(view, "#calculated-estimated-words")
  end

  test "shows a validation error when title is blank", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    html =
      view
      |> form("#add-book-form", book: %{title: " ", author: "Someone"})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#add-book-form")
  end

  test "saves a book, returns to the dashboard, and shows feedback", %{conn: conn} do
    reading_log = create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    result =
      view
      |> form("#add-book-form",
        book: %{
          title: "Le Petit Prince",
          author: "Antoine de Saint-Exupery",
          page_count: "96",
          estimated_words: "",
          difficulty_label: "Intermediate",
          status: "want_to_read",
          started_on: "",
          finished_on: "",
          notes: "Read one chapter a day."
        }
      )
      |> render_submit()

    assert {:error, {:live_redirect, %{to: "/"}}} = result

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Le Petit Prince"]]
      )

    assert book.author == "Antoine de Saint-Exupery"
    assert book.page_count == 96
    assert book.estimated_words == 24_000
    assert book.difficulty_label == "Intermediate"
    assert book.notes == "Read one chapter a day."

    {:ok, dashboard, html} = follow_redirect(result, conn)
    assert html =~ "Le Petit Prince was added to your reading log."
    assert has_element?(dashboard, "#books-want_to_read #book-#{book.id}")
  end

  test "adds an in-progress book with a default start date", %{conn: conn} do
    reading_log = create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    result =
      view
      |> form("#add-book-form",
        book: %{
          title: "L'Etranger",
          status: "in_progress",
          started_on: "",
          finished_on: ""
        }
      )
      |> render_submit()

    [book] =
      Library.list_books!(query: [filter: [reading_log_id: reading_log.id, title: "L'Etranger"]])

    assert book.status == :in_progress
    assert book.started_on == Date.utc_today()
    assert is_nil(book.finished_on)

    {:ok, dashboard, _html} = follow_redirect(result, conn)
    assert has_element?(dashboard, "#books-in_progress #book-#{book.id}")
    assert has_element?(dashboard, "#summary-books-in-progress", "1")
  end

  test "adds a finished book with default dates and completed-word stats", %{conn: conn} do
    reading_log = create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    result =
      view
      |> form("#add-book-form",
        book: %{
          title: "Le Petit Prince",
          estimated_words: "20000",
          status: "finished",
          started_on: "",
          finished_on: ""
        }
      )
      |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Le Petit Prince"]]
      )

    assert book.status == :finished
    assert book.started_on == Date.utc_today()
    assert book.finished_on == Date.utc_today()

    {:ok, dashboard, _html} = follow_redirect(result, conn)
    assert has_element?(dashboard, "#books-finished #book-#{book.id}")
    assert has_element?(dashboard, "#summary-books-finished", "1")
    assert has_element?(dashboard, "#words-completed", "20,000")
  end

  test "adds an abandoned book with explicitly supplied dates", %{conn: conn} do
    reading_log = create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    result =
      view
      |> form("#add-book-form",
        book: %{
          title: "Madame Bovary",
          status: "abandoned",
          started_on: "2026-05-01",
          finished_on: "2026-05-10"
        }
      )
      |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Madame Bovary"]]
      )

    assert book.status == :abandoned
    assert book.started_on == ~D[2026-05-01]
    assert book.finished_on == ~D[2026-05-10]

    {:ok, dashboard, _html} = follow_redirect(result, conn)
    assert has_element?(dashboard, "#books-abandoned #book-#{book.id}")
  end

  defp create_reading_log do
    Library.create_reading_log!("French", "fr", 100_000)
  end
end
