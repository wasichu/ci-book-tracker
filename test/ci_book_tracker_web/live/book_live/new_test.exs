defmodule CiBookTrackerWeb.BookLive.NewTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCover
  alias CiBookTracker.Library.BookMetadata.{GoogleBooks, OpenLibrary}

  test "requires a reading log", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/books/new")
  end

  test "shows a phone-friendly add book form", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)

    {:ok, view, _html} = live(conn, ~p"/books/new")

    assert has_element?(view, "#add-book-page")
    assert has_element?(view, "#add-book-form")
    assert has_element?(view, "#metadata-search-form")
    assert has_element?(view, "label", "Metadata source")
    assert has_element?(view, "#metadata_provider option[value='open_library']", "Open Library")
    assert has_element?(view, "#metadata_provider option[value='google_books']", "Google Books")
    assert has_element?(view, "#metadata_provider option[value='all']", "All providers")
    assert has_element?(view, "label", "Title, author, ISBN, or keywords")
    assert has_element?(view, "label", "Title")
    assert has_element?(view, "label", "Author")
    assert has_element?(view, "label", "Page count")
    assert has_element?(view, "label", "Estimated Total Words")
    assert has_element?(view, "#word-estimate-helper", "Word Estimate Helper")
    assert has_element?(view, "#word-estimate-helper", "The sample is never saved.")
    assert has_element?(view, "#apply-word-estimate[disabled]", "Apply Estimate")
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

  test "searches Google Books and prefills normalized metadata", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(GoogleBooks, self(), view.pid)

    Req.Test.stub(GoogleBooks, fn conn ->
      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "google-volume",
            "volumeInfo" => %{
              "title" => "Short Stories in Spanish",
              "authors" => ["Olly Richards"],
              "pageCount" => 240,
              "language" => "es",
              "publishedDate" => "2018-10-04",
              "imageLinks" => %{"thumbnail" => "https://books.google.com/cover.jpg"}
            }
          }
        ]
      })
    end)

    view
    |> form("#metadata-search-form",
      metadata: %{provider: "google_books", query: "short stories"}
    )
    |> render_submit()

    assert has_element?(view, "#metadata-results", "Short Stories in Spanish")
    assert has_element?(view, "#metadata-results", "Google Books")
    assert has_element?(view, "#metadata-results", "240 pages")

    view
    |> element("button[phx-click='select_metadata']")
    |> render_click()

    assert has_element?(view, "#book_title[value='Short Stories in Spanish']")
    assert has_element?(view, "#book_author[value='Olly Richards']")
    assert has_element?(view, "#book_page_count[value='240']")
    assert has_element?(view, "#calculated-estimated-words", "60,000")
    assert has_element?(view, "input[name='book[cover_provider]'][value='google_books']")

    assert has_element?(
             view,
             "input[name='book[cover_url]'][value='https://books.google.com/cover.jpg']"
           )
  end

  test "searches metadata and explicitly prefills the book form", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(OpenLibrary, self(), view.pid)
    Req.Test.allow(BookCover, self(), view.pid)

    Req.Test.stub(OpenLibrary, fn conn ->
      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL2W",
            "edition_key" => ["OL2M"],
            "title" => "Cien anos de soledad",
            "author_name" => ["Gabriel Garcia Marquez"],
            "first_publish_year" => 1967,
            "language" => ["spa"],
            "number_of_pages_median" => 417,
            "cover_i" => 456
          }
        ]
      })
    end)

    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, "cover")
    end)

    view
    |> form("#metadata-search-form", metadata: %{query: "solitude"})
    |> render_submit()

    assert has_element?(view, "#metadata-results", "Cien anos de soledad")
    assert has_element?(view, "#metadata-results", "417 pages")
    assert has_element?(view, "#book_title[value='']")

    view
    |> element("button[phx-click='select_metadata']")
    |> render_click()

    assert has_element?(view, "#metadata-message", "Review it before saving")
    assert has_element?(view, "#book_title[value='Cien anos de soledad']")
    assert has_element?(view, "#book_author[value='Gabriel Garcia Marquez']")
    assert has_element?(view, "#book_page_count[value='417']")
    assert has_element?(view, "#calculated-estimated-words", "104,250")
    assert has_element?(view, "input[name='book[cover_provider]'][value='open_library']")
    assert has_element?(view, "input[name='book[cover_id]'][value='456']")

    assert has_element?(
             view,
             "input[name='book[cover_url]'][value='https://covers.openlibrary.org/b/id/456-M.jpg']"
           )
  end

  test "saves selected metadata cover details with the book", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(OpenLibrary, self(), view.pid)
    Req.Test.allow(BookCover, self(), view.pid)

    Req.Test.stub(OpenLibrary, fn conn ->
      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL2W",
            "title" => "Cien anos de soledad",
            "cover_i" => 456
          }
        ]
      })
    end)

    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, "cover")
    end)

    view
    |> form("#metadata-search-form", metadata: %{query: "solitude"})
    |> render_submit()

    view
    |> element("button[phx-click='select_metadata']")
    |> render_click()

    view
    |> form("#add-book-form",
      book: %{
        title: "Cien anos de soledad",
        cover_url: "https://covers.openlibrary.org/b/id/456-M.jpg",
        cover_image_url: "https://covers.openlibrary.org/b/id/456-M.jpg",
        cover_provider: "open_library",
        cover_id: "456"
      }
    )
    |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Cien anos de soledad"]]
      )

    assert book.cover_provider == "open_library"
    assert book.cover_id == 456
    assert book.cover_url == "https://covers.openlibrary.org/b/id/456-M.jpg"
    assert book.cover_path =~ ".jpg"
    assert File.regular?(BookCover.local_path(book.cover_path))
  end

  test "downloads a manual cover URL when saving a book", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(BookCover, self(), view.pid)

    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, "manual cover")
    end)

    view
    |> form("#add-book-form",
      book: %{
        title: "Manual cover",
        cover_image_url: "https://example.com/manual-cover.jpg"
      }
    )
    |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Manual cover"]]
      )

    assert book.cover_url == "https://example.com/manual-cover.jpg"
    assert book.cover_path =~ ".jpg"
    assert File.regular?(BookCover.local_path(book.cover_path))
  end

  test "uploads cover art when saving a book", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    upload =
      file_input(view, "#add-book-form", :cover_art, [
        %{
          name: "cover.png",
          content: "uploaded cover",
          type: "image/png"
        }
      ])

    assert render_upload(upload, "cover.png") =~ "100%"

    view
    |> form("#add-book-form", book: %{title: "Uploaded cover"})
    |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Uploaded cover"]]
      )

    assert book.cover_provider == "local"
    assert book.cover_path =~ ".png"
    assert File.regular?(BookCover.local_path(book.cover_path))
  end

  test "uses only the cover from a metadata result", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form",
      book: %{title: "My title", author: "My author", page_count: "123"}
    )
    |> render_change()

    Req.Test.allow(OpenLibrary, self(), view.pid)

    Req.Test.stub(OpenLibrary, fn conn ->
      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL2W",
            "title" => "Provider title",
            "author_name" => ["Provider author"],
            "number_of_pages_median" => 417,
            "cover_i" => 456
          }
        ]
      })
    end)

    view
    |> form("#metadata-search-form", metadata: %{query: "provider title"})
    |> render_submit()

    assert has_element?(view, "button[phx-click='select_cover']", "Use cover only")

    view
    |> element("button[phx-click='select_cover']")
    |> render_click()

    assert has_element?(view, "#flash-info", "Cover added to the form")
    refute has_element?(view, "#metadata-message", "Cover added to the form")
    assert has_element?(view, "#book_title[value='My title']")
    assert has_element?(view, "#book_author[value='My author']")
    assert has_element?(view, "#book_page_count[value='123']")
    assert has_element?(view, "input[name='book[cover_provider]'][value='open_library']")
    assert has_element?(view, "input[name='book[cover_id]'][value='456']")
  end

  test "keeps manual entry available when metadata lookup fails", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(OpenLibrary, self(), view.pid)
    Req.Test.stub(OpenLibrary, &Req.Test.transport_error(&1, :econnrefused))

    view
    |> form("#metadata-search-form", metadata: %{query: "solitude"})
    |> render_submit()

    assert has_element?(view, "#metadata-message", "unavailable right now")
    assert has_element?(view, "#add-book-form")
  end

  test "explains Google Books quota failures", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    Req.Test.allow(GoogleBooks, self(), view.pid)

    Req.Test.stub(GoogleBooks, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{"error" => %{"status" => "RESOURCE_EXHAUSTED"}})
    end)

    view
    |> form("#metadata-search-form",
      metadata: %{provider: "google_books", query: "The Little Prince"}
    )
    |> render_submit()

    assert has_element?(view, "#metadata-message", "Configure GOOGLE_BOOKS_API_KEY")
    assert has_element?(view, "#add-book-form")
  end

  test "shows a read-only formatted total calculated from page count", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: ""})
    |> render_change()

    assert has_element?(view, "#calculated-estimated-words", "30,000")
    assert has_element?(view, "#calculated-estimated-words", "Using 250 words per page")
    assert has_element?(view, "input[name='book[estimated_words]'][type='hidden'][value='30000']")
    refute has_element?(view, "#book_estimated_words[type='number']")
  end

  test "preserves a manual estimate alongside page count", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "120", estimated_words: "27500"})
    |> render_change()

    refute has_element?(view, "#calculated-estimated-words")
    assert has_element?(view, "#book_estimated_words[type='number'][value='27500']")
  end

  test "replaces a page estimate with a custom total and saves it after changing pages", %{
    conn: conn
  } do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{title: "Known word count", page_count: "120"})
    |> render_change()

    view |> element("#enter-word-estimate") |> render_click()
    assert has_element?(view, "#book_estimated_words[type='number'][value='30000']")

    view
    |> form("#add-book-form", book: %{estimated_words: "27500"})
    |> render_change()

    view
    |> form("#add-book-form", book: %{page_count: "200"})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[value='27500']")
    refute has_element?(view, "#calculated-estimated-words")

    view |> form("#add-book-form") |> render_submit()

    [book] = Library.list_books!(query: [filter: [reading_log_id: reading_log.id]])
    assert book.page_count == 200
    assert book.estimated_words == 27_500
  end

  test "allows a manual total when page count is blank", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{page_count: "", estimated_words: "27500"})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[type='number'][value='27500']")
    refute has_element?(view, "#calculated-estimated-words")
  end

  test "clearing a manual total keeps it blank through page changes and saving", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{title: "No word estimate", estimated_words: "27500"})
    |> render_change()

    view
    |> form("#add-book-form", book: %{estimated_words: "", page_count: "120"})
    |> render_change()

    assert has_element?(view, "#book_estimated_words[type='number'][value='']")
    refute has_element?(view, "#calculated-estimated-words")

    view |> form("#add-book-form") |> render_submit()

    [book] = Library.list_books!(query: [filter: [reading_log_id: reading_log.id]])
    assert book.page_count == 120
    assert is_nil(book.estimated_words)
  end

  test "calculates and applies a sample-based word estimate", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form",
      book: %{title: "Sampled book", page_count: "180"},
      estimator: %{
        sample_text: "Uno dos tres cuatro cinco seis",
        sample_units: "2",
        total_units: "100",
        unit_type: "pages"
      }
    )
    |> render_change()

    assert has_element?(view, "#sample-word-count", "6")
    assert has_element?(view, "#sample-estimated-words", "300")
    refute has_element?(view, "#apply-word-estimate[disabled]")

    view |> element("#apply-word-estimate") |> render_click()

    assert has_element?(view, "#book_estimated_words[value='300']")
    assert has_element?(view, "input[name='book[estimated_words_mode]'][value='manual']")
    refute has_element?(view, "#calculated-estimated-words")

    view |> form("#add-book-form", book: %{page_count: "200"}) |> render_change()
    assert has_element?(view, "#book_estimated_words[value='300']")

    view |> form("#add-book-form") |> render_submit()

    [book] =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log.id, title: "Sampled book"]]
      )

    assert book.estimated_words == 300
    refute Map.has_key?(Map.from_struct(book), :sample_text)
  end

  test "shows a helpful error for an invalid sample range", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form",
      estimator: %{
        sample_text: "Uno dos tres",
        sample_units: "10",
        total_units: "5",
        unit_type: "chapters"
      }
    )
    |> render_change()

    assert has_element?(
             view,
             "#word-estimate-error",
             "Total unit count must be at least the sample unit count."
           )

    assert has_element?(view, "#apply-word-estimate[disabled]")
  end

  test "clears a calculated total when page count is removed", %{conn: conn} do
    {conn, _reading_log} = create_reading_log(conn)
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
    {conn, _reading_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    html =
      view
      |> form("#add-book-form", book: %{title: " ", author: "Someone"})
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#add-book-form")
  end

  test "saves a book, returns to the dashboard, and shows feedback", %{conn: conn} do
    {conn, reading_log} = create_reading_log(conn)
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

    assert {:error, {:live_redirect, %{to: "/dashboard"}}} = result

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
    {conn, reading_log} = create_reading_log(conn)
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
    {conn, reading_log} = create_reading_log(conn)
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
    {conn, reading_log} = create_reading_log(conn)
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

  test "adds books only to the active reading log", %{conn: conn} do
    inactive_log = Library.create_reading_log!("Spanish", "es", 50_000)
    {conn, active_log} = create_reading_log(conn)
    {:ok, view, _html} = live(conn, ~p"/books/new")

    view
    |> form("#add-book-form", book: %{title: "Active log book"})
    |> render_submit()

    assert [%{title: "Active log book"}] =
             Library.list_books!(query: [filter: [reading_log_id: active_log.id]])

    assert Library.list_books!(query: [filter: [reading_log_id: inactive_log.id]]) == []
  end

  defp create_reading_log(conn) do
    reading_log = Library.create_reading_log!("French", "fr", 100_000)
    conn = init_test_session(conn, %{"active_reading_log_id" => reading_log.id})
    {conn, reading_log}
  end
end
