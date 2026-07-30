defmodule CiBookTracker.Library.BookCoverTest do
  use CiBookTracker.DataCase

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCover

  test "downloads and stores a remote cover image" do
    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, "cover")
    end)

    assert {:ok, %{cover_path: cover_path, cover_url: cover_url}} =
             BookCover.store_url("https://example.com/cover.jpg")

    assert cover_url == "https://example.com/cover.jpg"
    assert cover_path =~ ".jpg"
    assert File.read!(BookCover.local_path(cover_path)) == "cover"
    assert BookCover.public_path(cover_path) == "/covers/#{cover_path}"
  end

  test "rejects non-image remote cover URLs" do
    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.resp(200, "not an image")
    end)

    assert {:error, :unsupported_type} = BookCover.store_url("https://example.com/cover")
  end

  test "stores an uploaded cover image" do
    source_path =
      Path.join([
        System.tmp_dir!(),
        "ci_book_tracker_cover_#{System.unique_integer([:positive])}.png"
      ])

    File.write!(source_path, "uploaded cover")

    assert {:ok, %{cover_path: cover_path, cover_url: nil}} =
             BookCover.store_upload(source_path, "cover.png")

    assert cover_path =~ ".png"
    assert File.read!(BookCover.local_path(cover_path)) == "uploaded cover"
  end

  test "backfills books that only have remote cover URLs" do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)

    remote_book =
      reading_log.id
      |> Library.add_book!("Remote cover")
      |> put_legacy_cover(%{
        cover_url: "https://example.com/remote.jpg",
        cover_provider: "open_library",
        cover_id: 123
      })

    local_book =
      Library.add_book_with_cover!(reading_log.id, "Local cover", %{
        cover_url: "https://example.com/local.jpg",
        cover_path: "already-local.jpg",
        cover_provider: "open_library"
      })

    Req.Test.stub(BookCover, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("image/jpeg")
      |> Plug.Conn.resp(200, "backfilled cover")
    end)

    assert %{downloaded: 1, skipped: skipped, failed: 0} = BookCover.backfill_remote_covers()
    assert skipped >= 1

    updated_remote = Library.get_book!(remote_book.id)
    updated_local = Library.get_book!(local_book.id)

    assert updated_remote.cover_path =~ ".jpg"
    assert updated_remote.cover_provider == "open_library"
    assert updated_remote.cover_id == 123
    assert File.read!(BookCover.local_path(updated_remote.cover_path)) == "backfilled cover"
    assert updated_local.cover_path == "already-local.jpg"
  end

  test "replacing and removing a cover cleans up stored files" do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    old_path = "old-#{System.unique_integer([:positive])}.jpg"
    new_path = "new-#{System.unique_integer([:positive])}.jpg"
    File.mkdir_p!(CiBookTracker.AppData.cover_directory())
    File.write!(BookCover.local_path(old_path), "old")
    File.write!(BookCover.local_path(new_path), "new")

    book =
      Library.add_book_with_cover!(reading_log.id, "Covered", %{
        cover_path: old_path,
        cover_provider: "local"
      })

    assert {:ok, updated} =
             BookCover.attach(book, %{
               cover_path: new_path,
               cover_provider: "local",
               cover_url: nil,
               cover_id: nil
             })

    refute File.exists?(BookCover.local_path(old_path))
    assert File.exists?(BookCover.local_path(new_path))

    assert {:ok, without_cover} = Library.remove_book_cover(updated)
    assert is_nil(without_cover.cover_path)
    refute File.exists?(BookCover.local_path(new_path))
  end

  test "deleting a book or reading log removes its local covers" do
    first_log = Library.create_reading_log!("Spanish", "es", nil)
    second_log = Library.create_reading_log!("French", "fr", nil)
    first_path = "delete-book-#{System.unique_integer([:positive])}.jpg"
    second_path = "delete-log-#{System.unique_integer([:positive])}.jpg"
    File.mkdir_p!(CiBookTracker.AppData.cover_directory())
    File.write!(BookCover.local_path(first_path), "first")
    File.write!(BookCover.local_path(second_path), "second")

    first_book =
      Library.add_book_with_cover!(first_log.id, "First", %{
        cover_path: first_path,
        cover_provider: "local"
      })

    Library.add_book_with_cover!(second_log.id, "Second", %{
      cover_path: second_path,
      cover_provider: "local"
    })

    assert :ok = Library.delete_book(first_book)
    refute File.exists?(BookCover.local_path(first_path))

    assert :ok = Library.delete_reading_log(second_log)
    refute File.exists?(BookCover.local_path(second_path))
  end

  test "a rejected attachment removes the newly stored file" do
    reading_log = Library.create_reading_log!("Spanish", "es", nil)
    book = Library.add_book!(reading_log.id, "Covered")
    new_path = "invalid-#{System.unique_integer([:positive])}.jpg"
    File.mkdir_p!(CiBookTracker.AppData.cover_directory())
    File.write!(BookCover.local_path(new_path), "new")

    assert {:error, _error} =
             BookCover.attach(book, %{
               cover_path: new_path,
               cover_provider: "local",
               cover_url: "https://example.com/not-local.jpg"
             })

    refute File.exists?(BookCover.local_path(new_path))
  end

  defp put_legacy_cover(book, attributes) do
    changeset = Ash.Changeset.for_update(book, :edit)

    attributes
    |> Enum.reduce(changeset, fn {attribute, value}, changeset ->
      Ash.Changeset.force_change_attribute(changeset, attribute, value)
    end)
    |> Ash.update!()
  end
end
