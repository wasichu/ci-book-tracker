defmodule CiBookTracker.Library.BookMetadata.GoogleBooks do
  @moduledoc """
  Google Books metadata provider.
  """

  @behaviour CiBookTracker.Library.BookMetadata

  alias CiBookTracker.Library.BookMetadata.{Normalization, Result, Search}
  alias CiBookTracker.Settings.MetadataProviders

  @base_url "https://www.googleapis.com/books/v1"
  @result_limit 8

  @impl true
  def search(query, opts \\ []) do
    query = String.trim(query)
    language_code = opts[:language_code]

    cond do
      !MetadataProviders.enabled?(:google_books) ->
        {:error, :provider_disabled}

      query == "" ->
        {:ok, %Search{query: query, results: [], status: :empty}}

      isbn = Normalization.isbn(query) ->
        search_isbn(isbn, query, language_code)

      true ->
        search_keywords(query, language_code)
    end
  end

  defp search_isbn(isbn, original_query, language_code) do
    case request("isbn:#{isbn}") do
      {:ok, [_item | _] = items} ->
        {:ok,
         %Search{
           query: original_query,
           results: normalize_and_rank(items, language_code),
           status: :ok
         }}

      {:ok, []} ->
        case request(original_query) do
          {:ok, items} ->
            {:ok,
             %Search{
               query: original_query,
               results: normalize_and_rank(items, language_code),
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
    case request(query) do
      {:ok, items} ->
        results = normalize_and_rank(items, language_code)
        status = if results == [], do: :empty, else: :ok
        {:ok, %Search{query: query, results: results, status: status}}

      error ->
        error
    end
  end

  defp request(query) do
    params =
      [q: query, maxResults: @result_limit, printType: "books"]
      |> maybe_put_api_key()

    options =
      [
        url: base_url() <> "/volumes",
        params: params,
        receive_timeout: 5_000,
        connect_options: [timeout: 3_000],
        retry: false
      ]
      |> Keyword.merge(request_options())

    case Req.get(options) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, List.wrap(body["items"])}

      {:ok, %{status: status, body: body}} when status in [403, 429] ->
        if quota_error?(body), do: {:error, :quota_exceeded}, else: {:error, :unavailable}

      {:ok, _response} ->
        {:error, :unavailable}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, _exception} ->
        {:error, :unavailable}
    end
  rescue
    _exception -> {:error, :unavailable}
  end

  defp normalize_and_rank(items, language_code) do
    items
    |> Enum.filter(
      &(is_binary(get_in(&1, ["volumeInfo", "title"])) &&
          get_in(&1, ["volumeInfo", "title"]) != "")
    )
    |> Enum.map(&normalize/1)
    |> Enum.sort_by(&rank(&1, language_code), :desc)
    |> Enum.take(@result_limit)
  end

  defp normalize(item) do
    info = item["volumeInfo"] || %{}
    provider_id = item["id"]
    cover_url = info |> get_in(["imageLinks", "thumbnail"]) |> Normalization.secure_url()

    %Result{
      id: "google_books:#{provider_id || info["title"]}",
      provider: :google_books,
      provider_id: provider_id,
      title: info["title"],
      author: info["authors"] |> List.wrap() |> Enum.join(", ") |> Normalization.empty_to_nil(),
      page_count: Normalization.positive_integer(info["pageCount"]),
      isbn_10: find_identifier(info["industryIdentifiers"], "ISBN_10"),
      isbn_13: find_identifier(info["industryIdentifiers"], "ISBN_13"),
      language_code: Normalization.language_code(info["language"]),
      publish_year: publish_year(info["publishedDate"]),
      cover_provider: cover_url && "google_books",
      cover_url: cover_url
    }
  end

  defp rank(result, language_code) do
    language_match = if language_code && result.language_code == language_code, do: 8, else: 0
    page_count = if result.page_count, do: 4, else: 0
    authors = if result.author, do: 2, else: 0
    cover = if result.cover_url, do: 2, else: 0
    published = if result.publish_year, do: 1, else: 0
    language_match + page_count + authors + cover + published
  end

  defp find_identifier(identifiers, type) do
    identifiers
    |> List.wrap()
    |> Enum.find_value(fn
      %{"type" => ^type, "identifier" => identifier} -> identifier
      _identifier -> nil
    end)
  end

  defp publish_year(value) when is_binary(value) do
    case Regex.run(~r/^\d{4}/, value) do
      [year] -> String.to_integer(year)
      _no_year -> nil
    end
  end

  defp publish_year(_value), do: nil

  defp quota_error?(%{"error" => error}) when is_map(error) do
    error["status"] == "RESOURCE_EXHAUSTED" ||
      Enum.any?(List.wrap(error["errors"]), &(&1["reason"] == "rateLimitExceeded")) ||
      Enum.any?(List.wrap(error["details"]), &(&1["reason"] == "RATE_LIMIT_EXCEEDED"))
  end

  defp quota_error?(_body), do: false

  defp maybe_put_api_key(params) do
    case config()[:api_key] || MetadataProviders.credential(:google_books) do
      key when is_binary(key) and key != "" -> Keyword.put(params, :key, key)
      _missing -> params
    end
  end

  defp base_url, do: config()[:base_url] || @base_url
  defp request_options, do: config()[:request_options] || []

  defp config do
    Application.get_env(:ci_book_tracker, __MODULE__, [])
  end
end
