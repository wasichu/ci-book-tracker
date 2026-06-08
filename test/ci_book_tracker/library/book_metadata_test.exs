defmodule CiBookTracker.Library.BookMetadataTest do
  use CiBookTracker.DataCase

  alias CiBookTracker.Library.BookMetadata
  alias CiBookTracker.Library.BookMetadata.{GoogleBooks, Hardcover, OpenLibrary}
  alias CiBookTracker.Settings.MetadataProviders

  test "normalizes and ranks Open Library search results" do
    Req.Test.stub(OpenLibrary, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["q"] == "solitude"
      assert conn.query_params["limit"] == "8"

      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL1W",
            "edition_key" => ["OL1M"],
            "title" => "One Hundred Years of Solitude",
            "author_name" => ["Gabriel Garcia Marquez"],
            "first_publish_year" => 1967,
            "language" => ["eng"],
            "isbn" => ["0307474720"],
            "cover_i" => 123
          },
          %{
            "key" => "/works/OL2W",
            "edition_key" => ["OL2M"],
            "title" => "Cien anos de soledad",
            "author_name" => ["Gabriel Garcia Marquez"],
            "first_publish_year" => 1967,
            "language" => ["spa", "eng"],
            "number_of_pages_median" => 417,
            "isbn" => ["9780307474728"],
            "cover_i" => 456
          }
        ]
      })
    end)

    assert {:ok, search} = BookMetadata.lookup_book("solitude", language_code: "spa")
    assert search.status == :ok

    assert [spanish, english] = search.results
    assert spanish.title == "Cien anos de soledad"
    assert spanish.author == "Gabriel Garcia Marquez"
    assert spanish.page_count == 417
    assert spanish.language_code == "es"
    assert spanish.isbn_13 == "9780307474728"
    assert spanish.open_library_work_key == "/works/OL2W"
    assert spanish.open_library_edition_key == "/books/OL2M"
    assert spanish.cover_url == "https://covers.openlibrary.org/b/id/456-M.jpg"
    assert english.isbn_10 == "0307474720"
  end

  test "normalizes a hyphenated ISBN and performs exact lookup first" do
    Req.Test.stub(OpenLibrary, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["isbn"] == "9780307474728"

      Req.Test.json(conn, %{
        "docs" => [
          %{
            "key" => "/works/OL2W",
            "edition_key" => ["OL2M"],
            "title" => "Cien anos de soledad",
            "isbn" => ["9780307474728"]
          }
        ]
      })
    end)

    assert {:ok, %{status: :ok, results: [%{title: "Cien anos de soledad"}]}} =
             BookMetadata.lookup_book("978-0307474728")
  end

  test "falls back to keyword search when an ISBN has no exact match" do
    Req.Test.expect(OpenLibrary, 2, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params do
        %{"isbn" => _isbn} ->
          Req.Test.json(conn, %{"docs" => []})

        %{"q" => "9780307474728"} ->
          Req.Test.json(conn, %{"docs" => []})
      end
    end)

    assert {:ok, search} = BookMetadata.lookup_book("9780307474728")
    assert search.status == :isbn_fallback
    assert search.results == []
    assert search.message == "No exact ISBN match found. Try searching by title or author."
  end

  test "returns a friendly error value for provider failures" do
    Req.Test.stub(OpenLibrary, &Req.Test.transport_error(&1, :econnrefused))

    assert {:error, :unavailable} = BookMetadata.lookup_book("The Little Prince")
  end

  test "normalizes and ranks Google Books search results without requiring an API key" do
    Req.Test.stub(GoogleBooks, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["q"] == "graded reader"
      assert conn.query_params["maxResults"] == "8"
      refute Map.has_key?(conn.query_params, "key")

      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "english-volume",
            "volumeInfo" => %{
              "title" => "An English Reader",
              "authors" => ["Example Author"],
              "language" => "en"
            }
          },
          %{
            "id" => "spanish-volume",
            "volumeInfo" => %{
              "title" => "Un lector graduado",
              "authors" => ["Ana Uno", "Luis Dos"],
              "pageCount" => 128,
              "language" => "es",
              "publishedDate" => "2021-04-10",
              "industryIdentifiers" => [
                %{"type" => "ISBN_10", "identifier" => "123456789X"},
                %{"type" => "ISBN_13", "identifier" => "9781234567897"}
              ],
              "imageLinks" => %{"thumbnail" => "http://books.google.com/cover.jpg"}
            }
          }
        ]
      })
    end)

    assert {:ok, search} =
             BookMetadata.lookup_book("graded reader",
               provider: :google_books,
               language_code: "es"
             )

    assert [spanish, english] = search.results
    assert spanish.id == "google_books:spanish-volume"
    assert spanish.provider == :google_books
    assert spanish.provider_id == "spanish-volume"
    assert spanish.title == "Un lector graduado"
    assert spanish.author == "Ana Uno, Luis Dos"
    assert spanish.page_count == 128
    assert spanish.isbn_10 == "123456789X"
    assert spanish.isbn_13 == "9781234567897"
    assert spanish.language_code == "es"
    assert spanish.publish_year == 2021
    assert spanish.cover_provider == "google_books"
    assert spanish.cover_url == "https://books.google.com/cover.jpg"
    assert english.title == "An English Reader"
  end

  test "Google Books normalizes an ISBN and falls back to a general query" do
    Req.Test.expect(GoogleBooks, 2, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["q"] do
        "isbn:9780307474728" ->
          Req.Test.json(conn, %{"totalItems" => 0})

        "978-0307474728" ->
          Req.Test.json(conn, %{
            "items" => [
              %{"id" => "fallback", "volumeInfo" => %{"title" => "Fallback edition"}}
            ]
          })
      end
    end)

    assert {:ok, search} =
             BookMetadata.lookup_book("978-0307474728", provider: :google_books)

    assert search.status == :isbn_fallback
    assert [%{title: "Fallback edition"}] = search.results
  end

  test "Google Books identifies quota exhaustion" do
    Req.Test.stub(GoogleBooks, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(%{
        "error" => %{
          "status" => "RESOURCE_EXHAUSTED",
          "errors" => [%{"reason" => "rateLimitExceeded"}]
        }
      })
    end)

    assert {:error, :quota_exceeded} =
             BookMetadata.lookup_book("The Little Prince", provider: :google_books)
  end

  test "all providers keeps successful results when one provider fails" do
    Req.Test.stub(OpenLibrary, &Req.Test.transport_error(&1, :econnrefused))

    Req.Test.stub(GoogleBooks, fn conn ->
      Req.Test.json(conn, %{
        "items" => [
          %{"id" => "available", "volumeInfo" => %{"title" => "Available Book"}}
        ]
      })
    end)

    assert {:ok, search} = BookMetadata.lookup_book("available", provider: :all)
    assert [%{title: "Available Book"}] = search.results
    assert search.message =~ "Some metadata sources were unavailable"
  end

  test "normalizes Hardcover GraphQL search results when configured" do
    assert {:ok, _setting} = MetadataProviders.save(:hardcover, true, "hardcover-token")

    Req.Test.stub(Hardcover, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer hardcover-token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      assert payload["variables"]["query"] == "cien anos"
      assert payload["query"] =~ "search"

      Req.Test.json(conn, %{
        "data" => %{
          "search" => %{
            "results" => [
              %{
                "id" => 42,
                "title" => "Cien anos de soledad",
                "author_names" => ["Gabriel Garcia Marquez"],
                "pages" => 417,
                "isbns" => ["0307474720", "9780307474728"],
                "language_code" => "es",
                "release_year" => 1967,
                "image" => %{"url" => "http://assets.hardcover.app/cover.jpg"}
              }
            ]
          }
        }
      })
    end)

    assert {:ok, %{status: :ok, results: [result]}} =
             BookMetadata.lookup_book("cien anos",
               provider: :hardcover,
               language_code: "es"
             )

    assert result.provider == :hardcover
    assert result.hardcover_id == "42"
    assert result.title == "Cien anos de soledad"
    assert result.author == "Gabriel Garcia Marquez"
    assert result.page_count == 417
    assert result.isbn_10 == "0307474720"
    assert result.isbn_13 == "9780307474728"
    assert result.language_code == "es"
    assert result.publish_year == 1967
    assert result.cover_provider == "hardcover"
    assert result.cover_url == "https://assets.hardcover.app/cover.jpg"
  end

  test "Hardcover remains unavailable without a token" do
    assert {:ok, _setting} = MetadataProviders.save(:hardcover, true, "")

    assert {:error, :provider_disabled} =
             BookMetadata.lookup_book("The Little Prince", provider: :hardcover)
  end

  test "Hardcover handles GraphQL errors without crashing" do
    assert {:ok, _setting} = MetadataProviders.save(:hardcover, true, "hardcover-token")

    Req.Test.stub(Hardcover, fn conn ->
      Req.Test.json(conn, %{"errors" => [%{"message" => "Search failed"}]})
    end)

    assert {:error, :graphql_error} =
             BookMetadata.lookup_book("The Little Prince", provider: :hardcover)
  end
end
