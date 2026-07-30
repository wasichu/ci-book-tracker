defmodule CiBookTrackerWeb.BookLive.FormParamsTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.Library.Book
  alias CiBookTrackerWeb.BookLive.FormParams

  test "normalizes text and separates book and cover attributes" do
    params =
      FormParams.empty()
      |> Map.merge(%{
        "title" => "  Title  ",
        "author" => "  Author ",
        "page_count" => "120",
        "cover_path" => "cover.jpg",
        "cover_provider" => "local"
      })
      |> FormParams.normalize()

    assert params["title"] == "Title"
    assert params["author"] == "Author"

    assert FormParams.book_attributes(params).page_count == "120"
    assert FormParams.book_attributes(params).author == "Author"

    assert FormParams.cover_attributes(params) == %{
             cover_id: nil,
             cover_path: "cover.jpg",
             cover_provider: "local",
             cover_url: nil
           }
  end

  test "calculates estimated words for a new book until a sample is selected" do
    assert %{
             "estimated_words" => "30000",
             "estimated_words_mode" => "calculated"
           } =
             FormParams.sync_estimated_words(
               %{"page_count" => "120", "estimated_words_mode" => "manual"},
               nil
             )

    sample = %{
      "page_count" => "120",
      "estimated_words" => "42000",
      "estimated_words_mode" => "sample"
    }

    assert FormParams.sync_estimated_words(sample, nil) == sample
  end

  test "applies full metadata to new books and preserves identity fields on edits" do
    result = %{
      title: "Metadata title",
      author: "Metadata author",
      page_count: 200,
      cover_url: "https://example.com/cover.jpg",
      cover_provider: "test",
      cover_id: 12
    }

    new_params = FormParams.apply_metadata(FormParams.empty(), result, :new)
    assert new_params["title"] == "Metadata title"
    assert new_params["author"] == "Metadata author"
    assert new_params["estimated_words"] == "50000"

    edit_params =
      FormParams.empty()
      |> Map.put("title", "Saved title")
      |> Map.put("author", "Saved author")
      |> FormParams.apply_metadata(result, :edit)

    assert edit_params["title"] == "Saved title"
    assert edit_params["author"] == "Saved author"
    assert edit_params["cover_id"] == "12"
  end

  test "serializes an existing book into form parameters" do
    book = %Book{
      title: "Book",
      status: :finished,
      page_count: 100,
      started_on: ~D[2026-01-02]
    }

    params = FormParams.initial(book)

    assert params["title"] == "Book"
    assert params["status"] == "finished"
    assert params["page_count"] == "100"
    assert params["started_on"] == "2026-01-02"
  end
end
