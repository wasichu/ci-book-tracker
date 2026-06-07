defmodule CiBookTracker.Library.BookMetadata do
  @moduledoc """
  Boundary for optional book metadata lookup.

  Manual book entry remains the primary workflow. A future implementation may
  supplement it with metadata from:

  * Open Library
  * Hardcover
  * Goodreads imports via Apify

  No provider is connected yet. Keeping lookup behind this module gives future
  integrations one place to normalize provider responses without coupling the
  book form or Library resources to an external service.
  """

  @type lookup_result :: %{
          query: String.t(),
          results: list(),
          status: :not_configured
        }

  @doc """
  Looks up metadata candidates for a title, author, or identifier.

  Returns an empty placeholder until a metadata provider is configured.
  """
  @spec lookup_book(String.t()) :: {:ok, lookup_result()}
  def lookup_book(query) when is_binary(query) do
    {:ok, %{query: query, results: [], status: :not_configured}}
  end
end
