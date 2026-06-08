defmodule CiBookTracker.Library.BookMetadata.Result do
  @moduledoc false

  @enforce_keys [:id, :title]
  defstruct [
    :id,
    :provider,
    :provider_id,
    :title,
    :author,
    :page_count,
    :isbn_10,
    :isbn_13,
    :language_code,
    :publish_year,
    :hardcover_id,
    :open_library_work_key,
    :open_library_edition_key,
    :cover_provider,
    :cover_id,
    :cover_url
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          provider: :open_library | :google_books | :hardcover,
          provider_id: String.t(),
          title: String.t(),
          author: String.t() | nil,
          page_count: pos_integer() | nil,
          isbn_10: String.t() | nil,
          isbn_13: String.t() | nil,
          language_code: String.t() | nil,
          publish_year: integer() | nil,
          hardcover_id: String.t() | nil,
          open_library_work_key: String.t() | nil,
          open_library_edition_key: String.t() | nil,
          cover_provider: String.t() | nil,
          cover_id: integer() | nil,
          cover_url: String.t() | nil
        }
end
