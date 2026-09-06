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

  test "automatically calculates and updates estimates until pages are removed" do
    params = FormParams.empty() |> FormParams.sync_estimated_words()
    assert params["estimated_words_mode"] == "unset"

    params = params |> Map.put("page_count", "120") |> FormParams.sync_estimated_words()
    assert params["estimated_words"] == "30000"
    assert params["estimated_words_mode"] == "calculated"

    params = params |> Map.put("page_count", "200") |> FormParams.sync_estimated_words()
    assert params["estimated_words"] == "50000"

    params = params |> Map.put("page_count", "") |> FormParams.sync_estimated_words()
    assert params["estimated_words"] == ""
    assert params["estimated_words_mode"] == "unset"
  end

  test "entering a total before pages selects manual mode" do
    params =
      FormParams.empty()
      |> Map.put("estimated_words", "42000")
      |> FormParams.sync_estimated_words()

    assert params["estimated_words_mode"] == "manual"

    params = params |> Map.put("page_count", "120") |> FormParams.sync_estimated_words()
    assert params["estimated_words"] == "42000"
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

    custom_params =
      FormParams.empty()
      |> Map.put("estimated_words", "27500")
      |> Map.put("estimated_words_mode", "manual")
      |> FormParams.apply_metadata(result, :new)

    assert custom_params["page_count"] == "200"
    assert custom_params["estimated_words"] == "27500"
    assert custom_params["estimated_words_mode"] == "manual"

    edit_params =
      FormParams.empty()
      |> Map.put("title", "Saved title")
      |> Map.put("author", "Saved author")
      |> FormParams.apply_metadata(result, :edit)

    assert edit_params["title"] == "Saved title"
    assert edit_params["author"] == "Saved author"
    assert edit_params["cover_id"] == "12"
    assert edit_params["estimated_words"] == "50000"
    assert edit_params["estimated_words_mode"] == "manual"

    changed_pages =
      edit_params |> Map.put("page_count", "300") |> FormParams.sync_estimated_words()

    assert changed_pages["estimated_words"] == "50000"
  end

  test "does not replace blank or invalid manual estimates with a page calculation" do
    for estimate <- ["", "0", "-1", "1.5"] do
      params = %{
        "page_count" => "120",
        "estimated_words" => estimate,
        "estimated_words_mode" => "manual"
      }

      assert FormParams.sync_estimated_words(params) == params
    end
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
