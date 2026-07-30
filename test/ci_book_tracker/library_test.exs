defmodule CiBookTracker.LibraryTest do
  use CiBookTracker.DataCase, async: true

  alias CiBookTracker.Library

  describe "reading logs and books" do
    test "creates a reading log and adds a book with defaults" do
      reading_log = create_reading_log()

      book = Library.add_book!(reading_log.id, "The Little Prince")

      assert reading_log.name == "French"
      assert reading_log.language_code == "fr"
      assert reading_log.word_goal == 100_000

      assert book.reading_log_id == reading_log.id
      assert book.title == "The Little Prince"
      assert book.status == :want_to_read
      assert book.added_on == Date.utc_today()
      assert is_nil(book.page_count)
      assert is_nil(book.estimated_words)
      assert is_nil(book.cover_url)
      assert is_nil(book.cover_provider)
      assert is_nil(book.cover_id)
      assert is_nil(book.notes)
    end

    test "requires a book title" do
      reading_log = create_reading_log()

      assert_raise Ash.Error.Invalid, fn ->
        Library.add_book!(reading_log.id, nil)
      end
    end

    test "creates a reading log without a word goal" do
      reading_log = Library.create_reading_log!("Spanish", "es", nil)

      assert reading_log.language_code == "es"
      assert is_nil(reading_log.word_goal)
    end

    test "edits a reading log without changing its id or books" do
      reading_log = create_reading_log()
      book = Library.add_book!(reading_log.id, "The Little Prince")

      updated =
        Library.edit_reading_log!(reading_log, %{
          name: "French classics",
          language_code: "fr",
          word_goal: 250_000
        })

      assert updated.id == reading_log.id
      assert updated.name == "French classics"
      assert updated.language_code == "fr"
      assert updated.word_goal == 250_000
      assert Library.get_book!(book.id).reading_log_id == reading_log.id
    end

    test "defaults reading dates from the initial status" do
      reading_log = create_reading_log()

      in_progress =
        Library.add_book!(reading_log.id, "Started", %{status: :in_progress})

      finished =
        Library.add_book!(reading_log.id, "Finished", %{status: :finished})

      historical =
        Library.add_book!(reading_log.id, "Historical", %{
          status: :finished,
          finished_on: ~D[2026-05-20]
        })

      assert in_progress.started_on == Date.utc_today()
      assert is_nil(in_progress.finished_on)
      assert finished.started_on == Date.utc_today()
      assert finished.finished_on == Date.utc_today()
      assert historical.started_on == ~D[2026-05-20]
      assert historical.finished_on == ~D[2026-05-20]
    end

    test "preserves explicitly supplied dates for any initial status" do
      reading_log = create_reading_log()

      want_to_read =
        Library.add_book!(reading_log.id, "Planned", %{
          status: :want_to_read,
          started_on: ~D[2026-05-01],
          finished_on: ~D[2026-05-02]
        })

      abandoned =
        Library.add_book!(reading_log.id, "Paused", %{
          status: :abandoned,
          started_on: ~D[2026-04-10],
          finished_on: ~D[2026-04-20]
        })

      assert want_to_read.started_on == ~D[2026-05-01]
      assert want_to_read.finished_on == ~D[2026-05-02]
      assert abandoned.started_on == ~D[2026-04-10]
      assert abandoned.finished_on == ~D[2026-04-20]
    end

    test "edits descriptive book fields" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "Le Petit Prince"))

      edited =
        Library.edit_book!(book, %{
          title: "Le Petit Prince",
          author: "Antoine de Saint-Exupery",
          page_count: 96,
          estimated_words: 16_000,
          difficulty_label: "Intermediate",
          notes: "Read one chapter each day."
        })

      edited =
        Library.attach_book_cover!(edited, %{
          cover_path: "cover.jpg",
          cover_url: "https://covers.openlibrary.org/b/id/123-M.jpg",
          cover_provider: "open_library",
          cover_id: 123
        })

      assert edited.author == "Antoine de Saint-Exupery"
      assert edited.page_count == 96
      assert edited.estimated_words == 16_000
      assert edited.cover_url == "https://covers.openlibrary.org/b/id/123-M.jpg"
      assert edited.cover_provider == "open_library"
      assert edited.cover_id == 123
      assert edited.difficulty_label == "Intermediate"
      assert edited.notes == "Read one chapter each day."
    end

    test "edits book fields and replaces its cover in one action" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "Original"))
        |> then(
          &Library.attach_book_cover!(&1, %{
            cover_path: "old.jpg",
            cover_url: nil,
            cover_provider: "local",
            cover_id: nil
          })
        )

      edited =
        Library.edit_book_with_cover!(book, %{
          title: "Edited",
          author: "Author",
          cover_path: "new.jpg",
          cover_url: "https://example.com/new.jpg",
          cover_provider: "test",
          cover_id: 10
        })

      assert edited.title == "Edited"
      assert edited.author == "Author"
      assert edited.cover_path == "new.jpg"
      assert edited.cover_url == "https://example.com/new.jpg"
    end

    test "does not persist ordinary edits when replacement cover validation fails" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "Original"))

      assert {:error, _error} =
               Library.edit_book_with_cover(book, %{
                 title: "Should not persist",
                 cover_path: "invalid.jpg",
                 cover_provider: "remote",
                 cover_url: nil
               })

      assert Library.get_book!(book.id).title == "Original"
    end

    test "edits book fields and removes its cover in one action" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "Original"))
        |> then(
          &Library.attach_book_cover!(&1, %{
            cover_path: "cover.jpg",
            cover_url: nil,
            cover_provider: "local",
            cover_id: nil
          })
        )

      edited = Library.edit_book_without_cover!(book, %{title: "Edited"})

      assert edited.title == "Edited"
      assert is_nil(edited.cover_path)
      assert is_nil(edited.cover_url)
      assert is_nil(edited.cover_provider)
      assert is_nil(edited.cover_id)
    end
  end

  describe "book lifecycle" do
    test "starts, finishes, reopens, and abandons a book" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "L'Etranger"))

      started = Library.start_book!(book)
      assert started.status == :in_progress
      assert started.started_on == Date.utc_today()
      assert is_nil(started.finished_on)

      finished = Library.finish_book!(started)
      assert finished.status == :finished
      assert finished.started_on == Date.utc_today()
      assert finished.finished_on == Date.utc_today()

      reopened = Library.reopen_book!(finished)
      assert reopened.status == :in_progress
      assert reopened.started_on == Date.utc_today()
      assert reopened.finished_on == Date.utc_today()

      abandoned = Library.abandon_book!(reopened)
      assert abandoned.status == :abandoned
      assert is_nil(abandoned.finished_on)
    end

    test "starting and reopening preserve the original start date" do
      original_started_on = Date.add(Date.utc_today(), -7)

      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "L'Etranger"))
        |> Ash.Changeset.for_update(:edit)
        |> Ash.Changeset.force_change_attribute(:started_on, original_started_on)
        |> Ash.update!()

      started = Library.start_book!(book)
      assert started.started_on == original_started_on

      reopened =
        started
        |> Library.finish_book!()
        |> Library.reopen_book!()

      assert reopened.started_on == original_started_on
    end

    test "finishing and abandoning backfill missing reading dates" do
      reading_log = create_reading_log()

      finished_on = Date.add(Date.utc_today(), -2)

      finished =
        reading_log.id
        |> Library.add_book!("Finished without a start", %{finished_on: finished_on})
        |> Library.finish_book!()

      abandoned =
        reading_log.id
        |> Library.add_book!("Abandoned without a start")
        |> Library.abandon_book!()

      assert finished.started_on == finished_on
      assert finished.finished_on == finished_on
      assert abandoned.started_on == Date.utc_today()
    end

    test "deletes a book" do
      book =
        create_reading_log()
        |> then(&Library.add_book!(&1.id, "Delete me"))

      assert :ok = Library.delete_book(book)
      assert {:error, _error} = Library.get_book(book.id)
    end
  end

  defp create_reading_log do
    Library.create_reading_log!("French", "fr", 100_000)
  end
end
