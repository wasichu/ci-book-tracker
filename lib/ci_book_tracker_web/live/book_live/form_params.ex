defmodule CiBookTrackerWeb.BookLive.FormParams do
  @moduledoc false

  alias CiBookTracker.Library.Book

  @empty %{
    "title" => "",
    "author" => "",
    "page_count" => "",
    "estimated_words" => "",
    "estimated_words_mode" => "unset",
    "cover_url" => "",
    "cover_path" => "",
    "cover_image_url" => "",
    "cover_provider" => "",
    "cover_id" => "",
    "difficulty_label" => "",
    "status" => "want_to_read",
    "started_on" => "",
    "finished_on" => "",
    "notes" => ""
  }

  @book_keys ~w(
    author
    page_count
    estimated_words
    difficulty_label
    status
    started_on
    finished_on
    notes
  )
  @cover_keys ~w(cover_url cover_path cover_provider cover_id)

  def empty, do: @empty

  def initial(nil), do: @empty

  def initial(%Book{} = book) do
    %{
      "title" => book.title || "",
      "author" => book.author || "",
      "page_count" => input_value(book.page_count),
      "estimated_words" => input_value(book.estimated_words),
      "estimated_words_mode" => "manual",
      "cover_url" => book.cover_url || "",
      "cover_path" => book.cover_path || "",
      "cover_image_url" => "",
      "cover_provider" => book.cover_provider || "",
      "cover_id" => input_value(book.cover_id),
      "difficulty_label" => book.difficulty_label || "",
      "status" => Atom.to_string(book.status),
      "started_on" => input_value(book.started_on),
      "finished_on" => input_value(book.finished_on),
      "notes" => book.notes || ""
    }
  end

  def normalize(params) do
    params = Map.merge(@empty, params)

    Enum.reduce(["title", "author", "difficulty_label"], params, fn key, normalized ->
      Map.update!(normalized, key, &String.trim/1)
    end)
  end

  def book_attributes(params), do: attributes(params, @book_keys)
  def cover_attributes(params), do: attributes(params, @cover_keys)

  def cover_changed?(%Book{} = book, cover_attributes) do
    Map.take(book, [:cover_url, :cover_path, :cover_provider, :cover_id]) != cover_attributes
  end

  @doc """
  Updates the word estimate according to the form's mode:

  * `unset`: choose manual entry when a total is supplied, otherwise estimate from pages.
  * `calculated`: keep the total in step with the page count; removing pages resets to unset.
  * `manual`: preserve the total, including blanks. Applied samples also use this mode.

  Existing books start in manual mode so editing their pages never changes their total.
  """
  def sync_estimated_words(%{"estimated_words_mode" => "manual"} = params), do: params

  def sync_estimated_words(%{"estimated_words_mode" => "calculated"} = params),
    do: calculate_estimated_words(params)

  def sync_estimated_words(params) do
    if blank?(params["estimated_words"]) do
      calculate_estimated_words(params)
    else
      Map.put(params, "estimated_words_mode", "manual")
    end
  end

  def apply_metadata(params, result, :new) do
    params
    |> Map.put("title", result.title)
    |> put_if_present("author", result.author)
    |> put_if_present("page_count", result.page_count)
    |> sync_estimated_words()
    |> apply_cover(result)
  end

  def apply_metadata(params, result, :edit) do
    params
    |> put_if_present("page_count", result.page_count)
    |> replace_estimate_from_metadata(result.page_count)
    |> apply_cover(result)
  end

  def apply_cover(params, result) do
    params
    |> Map.put("cover_url", result.cover_url || "")
    |> Map.put("cover_image_url", result.cover_url || "")
    |> Map.put("cover_path", "")
    |> Map.put("cover_provider", result.cover_provider || "")
    |> Map.put("cover_id", input_value(result.cover_id))
  end

  def calculated_estimate?(form), do: form[:estimated_words_mode].value == "calculated"

  def initial_metadata_query(%Book{} = book, true) do
    [book.title, book.author]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  def initial_metadata_query(_book, _metadata_refresh?), do: ""

  def cover_preview_url(form) do
    case form[:cover_image_url].value do
      value when is_binary(value) and value != "" -> value
      _blank -> form[:cover_url].value
    end
  end

  def cover_preview_title(form) do
    case form[:title].value do
      value when is_binary(value) and value != "" -> value
      _blank -> "Selected cover"
    end
  end

  def cover_preview_id(value) do
    case parse_positive_integer(value) do
      {:ok, cover_id} -> cover_id
      :error -> nil
    end
  end

  def blank?(value), do: value in [nil, ""]

  defp attributes(params, keys) do
    params
    |> Map.take(keys)
    |> Map.new(fn {key, value} -> {String.to_existing_atom(key), empty_to_nil(value)} end)
  end

  defp calculate_estimated_words(params) do
    case parse_positive_integer(params["page_count"]) do
      {:ok, page_count} ->
        params
        |> Map.put("estimated_words", words_from_pages(page_count))
        |> Map.put("estimated_words_mode", "calculated")

      :error ->
        params
        |> Map.put("estimated_words", "")
        |> Map.put("estimated_words_mode", "unset")
    end
  end

  defp put_if_present(params, _key, nil), do: params
  defp put_if_present(params, key, value), do: Map.put(params, key, to_string(value))

  defp replace_estimate_from_metadata(params, nil), do: params

  # Applying reviewed metadata explicitly replaces the total once. Subsequent page
  # edits leave it alone, just like any other estimate on an existing book.
  defp replace_estimate_from_metadata(params, page_count) do
    params
    |> Map.put("estimated_words", words_from_pages(page_count))
    |> Map.put("estimated_words_mode", "manual")
  end

  defp words_from_pages(page_count), do: Integer.to_string(page_count * 250)

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _other -> :error
    end
  end

  defp parse_positive_integer(_value), do: :error

  defp empty_to_nil(value) when value in [nil, ""], do: nil
  defp empty_to_nil(value), do: value

  defp input_value(nil), do: ""
  defp input_value(%Date{} = value), do: Date.to_iso8601(value)
  defp input_value(value), do: to_string(value)
end
