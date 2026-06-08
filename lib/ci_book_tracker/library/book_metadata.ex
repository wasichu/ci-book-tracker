defmodule CiBookTracker.Library.BookMetadata do
  @moduledoc """
  Boundary for optional, user-initiated book metadata lookup.

  Providers normalize their responses into `Result` values so forms never
  depend on provider-specific response shapes.
  """

  alias CiBookTracker.Library.BookMetadata.Search
  alias CiBookTracker.Settings.MetadataProviders

  @type provider :: :open_library | :google_books | :hardcover | :all
  @type lookup_option ::
          {:language_code, String.t() | nil}
          | {:provider, provider()}

  @callback search(String.t(), keyword()) :: {:ok, Search.t()} | {:error, atom()}

  @doc """
  Looks up metadata candidates for a title, author, ISBN, or general query.
  """
  @spec lookup_book(String.t(), [lookup_option()]) ::
          {:ok, Search.t()} | {:error, atom()}
  def lookup_book(query, opts \\ []) when is_binary(query) do
    case Keyword.get(opts, :provider, :open_library) do
      :all -> search_all(query, opts)
      provider -> provider_module(provider).search(query, opts)
    end
  end

  defp search_all(query, opts) do
    results =
      MetadataProviders.enabled_search_providers()
      |> Enum.map(&provider_module(&1).search(query, opts))

    searches = for {:ok, search} <- results, do: search
    errors = for {:error, reason} <- results, do: reason
    books = searches |> Enum.flat_map(& &1.results) |> Enum.take(10)

    cond do
      searches == [] ->
        {:error, List.first(errors) || :unavailable}

      books == [] ->
        {:ok,
         %Search{
           query: String.trim(query),
           results: [],
           status: :empty,
           message: partial_failure_message(errors)
         }}

      true ->
        {:ok,
         %Search{
           query: String.trim(query),
           results: books,
           status: :ok,
           message: partial_failure_message(errors)
         }}
    end
  end

  defp partial_failure_message([]), do: nil

  defp partial_failure_message(_errors),
    do: "Some metadata sources were unavailable. Showing the results we could find."

  defp provider_module(:open_library),
    do: CiBookTracker.Library.BookMetadata.OpenLibrary

  defp provider_module(:google_books),
    do: CiBookTracker.Library.BookMetadata.GoogleBooks

  defp provider_module(:hardcover),
    do: CiBookTracker.Library.BookMetadata.Hardcover
end
