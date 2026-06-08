defmodule CiBookTrackerWeb.BookLive.ImportTest do
  use CiBookTrackerWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiBookTracker.Library

  test "requires an active reading log", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/books/import")
  end

  test "previews row errors and imports valid books", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = init_test_session(conn, active_reading_log_id: reading_log.id)
    {:ok, view, _html} = live(conn, ~p"/books/import")

    upload =
      file_input(view, "#csv-upload-form", :csv, [
        %{
          name: "books.csv",
          content: "title,status,page_count\nValid,finished,20\n,unknown,nope\n",
          type: "text/csv"
        }
      ])

    assert render_upload(upload, "books.csv") =~ "100%"

    view
    |> form("#csv-upload-form")
    |> render_submit()

    assert has_element?(view, "#import-preview", "1 valid, 1 invalid")
    assert has_element?(view, "#import-row-3", "title is required")
    assert has_element?(view, "#confirm-import", "Import 1 book")

    view |> element("#confirm-import") |> render_click()

    assert has_element?(view, "#import-summary", "Imported 1 book")

    assert [%{title: "Valid", status: :finished, estimated_words: 5_000}] =
             Library.list_books!(query: [filter: [reading_log_id: reading_log.id]])
  end

  test "dashboard links to CSV import", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = init_test_session(conn, active_reading_log_id: reading_log.id)
    {:ok, view, _html} = live(conn, ~p"/dashboard")

    assert has_element?(view, "#import-books[href='/books/import']", "Import CSV")
  end

  test "explains required fields and allowed statuses", %{conn: conn} do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    conn = init_test_session(conn, active_reading_log_id: reading_log.id)
    {:ok, view, _html} = live(conn, ~p"/books/import")

    assert has_element?(view, "section", "Required fields")
    assert has_element?(view, "section", "title")
    assert has_element?(view, "section", "want_to_read, in_progress, finished, abandoned")
    assert has_element?(view, "section", "Date format")
    assert has_element?(view, "section", "YYYY-MM-DD")
    assert has_element?(view, "section", "All other fields are optional")

    assert has_element?(view, "#csv-header-help", "Title Column")
    assert has_element?(view, "#csv-header-help", "The first row in your CSV file")

    assert has_element?(
             view,
             "#csv-header-value",
             "title,author,status,page_count,estimated_words,difficulty_label,started_on,finished_on,notes"
           )

    assert has_element?(view, "#copy-csv-header[phx-hook='ClipboardCopy']", "Copy header")
    refute has_element?(view, "h2", "Supported Columns")
  end
end
