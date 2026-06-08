defmodule CiBookTracker.Library.BookCsvImportTest do
  use CiBookTracker.DataCase, async: true

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCsvImport

  test "previews valid rows and applies import defaults" do
    csv = """
    title,author,status,page_count,estimated_words,difficulty_label,started_on,finished_on,notes
    Hola Lola,Juan Fernández,,146,,A1,,,"Easy, cheerful reader"
    Finished Book,,finished,,,,,,Done
    """

    assert {:ok, preview} = BookCsvImport.preview(csv, ~D[2026-06-08])
    assert preview.valid_count == 2
    assert preview.invalid_count == 0

    [first, second] = preview.rows
    assert first.attributes.status == :want_to_read
    assert first.attributes.estimated_words == 36_500
    assert first.attributes.notes == "Easy, cheerful reader"
    assert second.attributes.started_on == ~D[2026-06-08]
    assert second.attributes.finished_on == ~D[2026-06-08]
  end

  test "reports file and row validation errors without hiding valid rows" do
    csv = """
    title,status,page_count,started_on
    Valid Book,in_progress,100,2026-05-01
    ,unknown,-2,05/02/2026
    """

    assert {:ok, preview} = BookCsvImport.preview(csv)
    assert preview.valid_count == 1
    assert preview.invalid_count == 1
    assert Enum.any?(List.last(preview.rows).errors, &(&1 == "title is required"))
    assert Enum.any?(List.last(preview.rows).errors, &String.starts_with?(&1, "status must"))

    assert {:error, ["The CSV must include a title column."]} =
             BookCsvImport.preview("author,status\nSomeone,finished\n")
  end

  test "supports escaped quotes and newlines in quoted fields" do
    csv = "title,notes\n\"A \"\"Quoted\"\" Book\",\"Line one\nLine two\"\n"

    assert {:ok, %{rows: [row]}} = BookCsvImport.preview(csv)
    assert row.attributes.title == ~s(A "Quoted" Book)
    assert row.attributes.notes == "Line one\nLine two"
  end

  test "imports only valid rows into the selected reading log" do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    other_log = Library.create_reading_log!("French", "fr", nil)
    csv = "title,status,page_count\nImported,finished,40\n,finished,20\n"

    assert {:ok, preview} = BookCsvImport.preview(csv, ~D[2026-06-08])
    assert %{imported: 1, failed: []} = BookCsvImport.import(preview, reading_log.id)

    assert [%{title: "Imported", reading_log_id: reading_log_id, estimated_words: 10_000}] =
             Library.list_books!(query: [filter: [reading_log_id: reading_log.id]])

    assert reading_log_id == reading_log.id
    assert [] = Library.list_books!(query: [filter: [reading_log_id: other_log.id]])
  end
end
