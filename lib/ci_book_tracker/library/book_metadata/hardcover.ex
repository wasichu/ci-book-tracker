defmodule CiBookTracker.Library.BookMetadata.Hardcover do
  @moduledoc """
  Hardcover GraphQL metadata provider.
  """

  @behaviour CiBookTracker.Library.BookMetadata

  alias CiBookTracker.Library.BookMetadata.{Normalization, Result, Search}
  alias CiBookTracker.Settings.MetadataProviders

  @base_url "https://api.hardcover.app/v1/graphql"
  @result_limit 8

  @query """
  query SearchBooks($query: String!) {
    search(query: $query, query_type: "Book", per_page: 8, page: 1) {
      results
    }
  }
  """

  @impl true
  def search(query, opts \\ []) do
    query = String.trim(query)

    cond do
      query == "" ->
        {:ok, %Search{query: query, results: [], status: :empty}}

      !MetadataProviders.enabled?(:hardcover) ->
        {:error, :provider_disabled}

      is_nil(token()) ->
        {:error, :missing_token}

      true ->
        request(query, opts[:language_code])
    end
  end

  defp request(query, language_code) do
    options =
      [
        url: base_url(),
        json: %{query: @query, variables: %{query: query}},
        headers: [
          {"authorization", "Bearer #{token()}"},
          {"user-agent", "CI Book Tracker/0.1"}
        ],
        receive_timeout: 8_000,
        connect_options: [timeout: 3_000],
        retry: false
      ]
      |> Keyword.merge(request_options())

    case Req.post(options) do
      {:ok, %{status: 200, body: %{"errors" => [_ | _]}}} ->
        {:error, :graphql_error}

      {:ok, %{status: 200, body: body}} when is_map(body) ->
        results =
          body
          |> get_in(["data", "search", "results"])
          |> normalize_results()
          |> Enum.sort_by(&rank(&1, language_code), :desc)
          |> Enum.take(@result_limit)

        status = if results == [], do: :empty, else: :ok
        {:ok, %Search{query: query, results: results, status: status}}

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: 429}} ->
        {:error, :quota_exceeded}

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

  defp normalize_results(results) when is_list(results) do
    results
    |> Enum.filter(&(is_map(&1) && present?(&1["title"])))
    |> Enum.map(&normalize/1)
  end

  defp normalize_results(_results), do: []

  defp normalize(book) do
    hardcover_id = string_value(book["id"] || book["slug"])
    cover_url = cover_url(book)
    {isbn_10, isbn_13} = isbns(book["isbns"])

    %Result{
      id: "hardcover:#{hardcover_id || book["title"]}",
      provider: :hardcover,
      provider_id: hardcover_id,
      hardcover_id: hardcover_id,
      title: book["title"],
      author: author(book),
      page_count: Normalization.positive_integer_string(book["pages"]),
      isbn_10: isbn_10,
      isbn_13: isbn_13,
      language_code: language_code(book),
      publish_year: Normalization.positive_integer_string(book["release_year"]),
      cover_provider: cover_url && "hardcover",
      cover_url: cover_url
    }
  end

  defp author(book) do
    book["author_names"]
    |> List.wrap()
    |> Enum.map(&author_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
    |> Normalization.empty_to_nil()
  end

  defp author_name(name) when is_binary(name), do: name
  defp author_name(%{"name" => name}) when is_binary(name), do: name
  defp author_name(_name), do: nil

  defp isbns(values) do
    values
    |> List.wrap()
    |> Enum.map(&isbn_value/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce({nil, nil}, fn isbn, {isbn_10, isbn_13} ->
      normalized = String.replace(isbn, ~r/[\s-]/, "")

      case String.length(normalized) do
        10 -> {isbn_10 || normalized, isbn_13}
        13 -> {isbn_10, isbn_13 || normalized}
        _length -> {isbn_10, isbn_13}
      end
    end)
  end

  defp isbn_value(value) when is_binary(value), do: value
  defp isbn_value(%{"isbn_10" => value}) when is_binary(value), do: value
  defp isbn_value(%{"isbn_13" => value}) when is_binary(value), do: value
  defp isbn_value(_value), do: nil

  defp cover_url(%{"image" => %{"url" => url}}) when is_binary(url),
    do: Normalization.secure_url(url)

  defp cover_url(%{"cover_url" => url}) when is_binary(url),
    do: Normalization.secure_url(url)

  defp cover_url(_book), do: nil

  defp language_code(%{"language" => %{"code2" => code}}),
    do: Normalization.language_code(code)

  defp language_code(%{"language_code" => code}), do: Normalization.language_code(code)
  defp language_code(_book), do: nil

  defp rank(result, language_code) do
    language_match = if language_code && result.language_code == language_code, do: 8, else: 0
    page_count = if result.page_count, do: 4, else: 0
    author = if result.author, do: 2, else: 0
    cover = if result.cover_url, do: 2, else: 0
    published = if result.publish_year, do: 1, else: 0
    language_match + page_count + author + cover + published
  end

  defp token, do: config()[:api_token] || MetadataProviders.credential(:hardcover)
  defp base_url, do: config()[:base_url] || @base_url
  defp request_options, do: config()[:request_options] || []
  defp config, do: Application.get_env(:ci_book_tracker, __MODULE__, [])

  defp string_value(value) when is_binary(value), do: value
  defp string_value(value) when is_integer(value), do: Integer.to_string(value)
  defp string_value(_value), do: nil

  defp present?(value), do: is_binary(value) && value != ""
end
