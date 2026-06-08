defmodule CiBookTracker.Library.BookMetadata.OpenLibrary do
  @moduledoc """
  Open Library metadata provider.
  """

  @behaviour CiBookTracker.Library.BookMetadata

  alias CiBookTracker.Library.BookMetadata.{Normalization, Result, Search}

  @base_url "https://openlibrary.org"
  @result_limit 8
  @fields Enum.join(
            ~w(key edition_key title author_name first_publish_year language
               number_of_pages_median isbn cover_i),
            ","
          )

  @impl true
  def search(query, opts \\ []) do
    query = String.trim(query)
    language_code = opts[:language_code]

    cond do
      query == "" ->
        {:ok, %Search{query: query, results: [], status: :empty}}

      isbn = Normalization.isbn(query) ->
        search_isbn(isbn, query, language_code)

      true ->
        search_keywords(query, language_code)
    end
  end

  defp search_isbn(isbn, original_query, language_code) do
    case request(isbn: isbn) do
      {:ok, [doc | _]} ->
        {:ok,
         %Search{
           query: original_query,
           results: normalize_and_rank([doc], language_code),
           status: :ok
         }}

      {:ok, []} ->
        case request(q: original_query) do
          {:ok, docs} ->
            {:ok,
             %Search{
               query: original_query,
               results: normalize_and_rank(docs, language_code),
               status: :isbn_fallback,
               message: "No exact ISBN match found. Try searching by title or author."
             }}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp search_keywords(query, language_code) do
    case request(q: query) do
      {:ok, docs} ->
        results = normalize_and_rank(docs, language_code)
        status = if results == [], do: :empty, else: :ok
        {:ok, %Search{query: query, results: results, status: status}}

      error ->
        error
    end
  end

  defp request(search_param) do
    options =
      [
        url: base_url() <> "/search.json",
        params: search_param ++ [fields: @fields, limit: @result_limit],
        headers: [{"user-agent", "ComprehensibleInputReadingLog/0.1"}],
        receive_timeout: 5_000,
        connect_options: [timeout: 3_000],
        retry: false
      ]
      |> Keyword.merge(request_options())

    case Req.get(options) do
      {:ok, %{status: 200, body: %{"docs" => docs}}} when is_list(docs) -> {:ok, docs}
      {:ok, _response} -> {:error, :unavailable}
      {:error, %{reason: :timeout}} -> {:error, :timeout}
      {:error, _exception} -> {:error, :unavailable}
    end
  rescue
    _exception -> {:error, :unavailable}
  end

  defp normalize_and_rank(docs, language_code) do
    docs
    |> Enum.filter(&(is_binary(&1["title"]) && &1["title"] != ""))
    |> Enum.map(&normalize/1)
    |> Enum.sort_by(&rank(&1, language_code), :desc)
    |> Enum.take(@result_limit)
  end

  defp normalize(doc) do
    cover_id = doc["cover_i"]
    isbn_10 = find_isbn(doc["isbn"], 10)
    isbn_13 = find_isbn(doc["isbn"], 13)
    work_key = doc["key"]
    edition_key = List.first(doc["edition_key"] || [])

    %Result{
      id:
        "open_library:" <>
          (edition_key || work_key || "#{doc["title"]}-#{doc["first_publish_year"]}"),
      provider: :open_library,
      provider_id: edition_key || work_key,
      title: doc["title"],
      author:
        doc["author_name"] |> List.wrap() |> Enum.join(", ") |> Normalization.empty_to_nil(),
      page_count: Normalization.positive_integer(doc["number_of_pages_median"]),
      isbn_10: isbn_10,
      isbn_13: isbn_13,
      language_code:
        doc["language"] |> List.wrap() |> List.first() |> Normalization.language_code(),
      publish_year: Normalization.positive_integer(doc["first_publish_year"]),
      open_library_work_key: work_key,
      open_library_edition_key: edition_key && "/books/#{edition_key}",
      cover_provider: cover_id && "open_library",
      cover_id: cover_id,
      cover_url: cover_id && "https://covers.openlibrary.org/b/id/#{cover_id}-M.jpg"
    }
  end

  defp rank(result, language_code) do
    language_match = if language_code && result.language_code == language_code, do: 8, else: 0
    page_count = if result.page_count, do: 4, else: 0
    cover = if result.cover_id, do: 2, else: 0
    identifiers = if result.isbn_10 || result.isbn_13, do: 1, else: 0
    language_match + page_count + cover + identifiers
  end

  defp find_isbn(isbns, length) do
    isbns
    |> List.wrap()
    |> Enum.find(&(String.length(&1) == length))
  end

  defp base_url do
    Application.get_env(:ci_book_tracker, __MODULE__, [])[:base_url] || @base_url
  end

  defp request_options do
    Application.get_env(:ci_book_tracker, __MODULE__, [])[:request_options] || []
  end
end
