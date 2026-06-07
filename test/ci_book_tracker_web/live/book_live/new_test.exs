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
    assert has_element?(view, "label", "Estimated words")
    assert has_element?(view, "label", "Difficulty")
    assert has_element?(view, "label", "Notes")
    assert has_element?(view, "#save-book", "Save Book")
  end

  test "estimates words from page count when the estimate is blank", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: ""})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[value='30000']")
  end

  test "preserves a user-edited word estimate", %{conn: conn} do
    create_reading_log()
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: "27500"})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[value='27500']")
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

  defp create_reading_log do
    Library.create_reading_log!("French", "fr", 100_000)
  end
end
