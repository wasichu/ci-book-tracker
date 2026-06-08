defmodule CiBookTracker.Settings.MetadataProvidersTest do
  use CiBookTracker.DataCase

  alias CiBookTracker.Settings.MetadataProviders

  test "persists Google Books settings" do
    assert {:ok, _setting} = MetadataProviders.save(:google_books, false, "google-key")

    assert %{enabled: false, credential: "google-key"} =
             MetadataProviders.get(:google_books)
  end

  test "persists Hardcover token updates and removal" do
    assert {:ok, _setting} = MetadataProviders.save(:hardcover, true, "first-token")
    assert MetadataProviders.configured?(:hardcover)

    assert {:ok, _setting} = MetadataProviders.save(:hardcover, true, "second-token")
    assert MetadataProviders.credential(:hardcover) == "second-token"

    assert {:ok, _setting} = MetadataProviders.save(:hardcover, false, "")
    refute MetadataProviders.configured?(:hardcover)
    assert MetadataProviders.credential(:hardcover) == nil
  end

  test "Open Library is always enabled" do
    assert MetadataProviders.enabled?(:open_library)
    assert :open_library in MetadataProviders.enabled_search_providers()
  end
end
