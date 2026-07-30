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
      Library.add_book!(reading_log.id, "Remote cover", %{
        cover_url: "https://example.com/remote.jpg",
        cover_provider: "open_library",
        cover_id: 123
      })

    local_book =
      Library.add_book!(reading_log.id, "Local cover", %{
        cover_url: "https://example.com/local.jpg",
        cover_path: "already-local.jpg"
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
end
