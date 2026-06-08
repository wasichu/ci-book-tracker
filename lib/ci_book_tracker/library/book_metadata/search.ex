defmodule CiBookTracker.Library.BookMetadata.Search do
  @moduledoc false

  alias CiBookTracker.Library.BookMetadata.Result

  @enforce_keys [:query, :results, :status]
  defstruct [:query, :results, :status, :message]

  @type t :: %__MODULE__{
          query: String.t(),
          results: [Result.t()],
          status: :ok | :empty | :isbn_fallback,
          message: String.t() | nil
        }
end
