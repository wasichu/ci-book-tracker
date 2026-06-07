defmodule CiBookTracker.Library.BookMetadataTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.Library.BookMetadata

  test "returns the placeholder response without performing a lookup" do
    assert {:ok,
            %{
              query: "Le Petit Prince",
              results: [],
              status: :not_configured
            }} = BookMetadata.lookup_book("Le Petit Prince")
  end
end
