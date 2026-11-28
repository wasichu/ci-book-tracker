# Isolated, disposable preview data; never uses the personal reading-log directory.
preview_directory = Path.join(System.tmp_dir!(), "ci-book-tracker-screenshot-preview")
File.mkdir_p!(preview_directory)
Application.put_env(:ci_book_tracker, :app_data_directory, preview_directory)
Application.put_env(:ci_book_tracker, :migrate_on_start, true)
repo = Application.fetch_env!(:ci_book_tracker, CiBookTracker.Repo)

Application.put_env(
  :ci_book_tracker,
  CiBookTracker.Repo,
  Keyword.put(repo, :database, Path.join(preview_directory, "reading_log.db"))
)

endpoint = Application.fetch_env!(:ci_book_tracker, CiBookTrackerWeb.Endpoint)

Application.put_env(
  :ci_book_tracker,
  CiBookTrackerWeb.Endpoint,
  Keyword.merge(endpoint, http: [ip: {127, 0, 0, 1}, port: 4200], server: true, watchers: [])
)

{:ok, _} = Application.ensure_all_started(:ci_book_tracker)

alias CiBookTracker.Library
alias CiBookTracker.Library.BookCover

log =
  case Library.list_reading_logs!() do
    [] ->
      log = Library.create_reading_log!("Spanish reading", "es", 1_000_000)
      Library.create_reading_log!("French reading", "fr", 500_000)

      samples = [
        {"La sombra del viento", "Carlos Ruiz Zafón", 487, 155_000, "B2", :in_progress,
         "9780143034902"},
        {"El principito", "Antoine de Saint-Exupéry", 96, 17_000, "A2", :finished,
         "9780156012195"},
        {"Como agua para chocolate", "Laura Esquivel", 256, 62_000, "B1", :want_to_read,
         "9780385420174"},
        {"Cien años de soledad", "Gabriel García Márquez", 417, 144_000, "C1", :want_to_read,
         "9780060883287"},
        {"La casa de los espíritus", "Isabel Allende", 448, 142_000, "B2", :want_to_read, nil},
        {"Crónica de una muerte anunciada", "Gabriel García Márquez", 128, 33_000, "B1",
         :finished, nil},
        {"La tregua", "Mario Benedetti", 208, 52_000, "B1", :finished, nil},
        {"Ficciones", "Jorge Luis Borges", 224, 58_000, "C1", :want_to_read, nil},
        {"Nada", "Carmen Laforet", 304, 77_000, "B2", :abandoned, nil},
        {"El túnel", "Ernesto Sabato", 160, 38_000, "B2", :want_to_read, nil}
      ]

      for {title, author, pages, words, level, status, isbn} <- samples do
        book =
          Library.add_book!(log.id, title, %{
            author: author,
            page_count: pages,
            estimated_words: words,
            difficulty_label: level,
            status: status,
            notes:
              "A sample reading note. Pick out new expressions, enjoy the story, and return for another chapter tomorrow."
          })

        if isbn do
          url = "https://covers.openlibrary.org/b/isbn/#{isbn}-M.jpg?default=false"

          with {:ok, %{status: 200, body: body}} <-
                 Req.get(url, decode_body: false, retry: false, receive_timeout: 6000),
               temporary = Path.join(preview_directory, "#{isbn}.jpg"),
               :ok <- File.write(temporary, body),
               {:ok, cover} <- BookCover.store_upload(temporary, "#{isbn}.jpg") do
            Library.attach_book_cover!(book, Map.merge(cover, %{cover_provider: "local"}))
          else
            _ -> IO.puts("Cover unavailable for #{title}; using the built-in placeholder.")
          end
        end
      end

      log

    logs ->
      Enum.find(logs, &(&1.language_code == "es")) || hd(logs)
  end

IO.puts("WORKBENCH PREVIEW: http://localhost:4200/reading-logs/#{log.id}/open")
Process.sleep(:infinity)
