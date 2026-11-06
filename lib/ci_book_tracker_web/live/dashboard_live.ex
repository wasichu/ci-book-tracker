defmodule CiBookTrackerWeb.DashboardLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library

  alias CiBookTrackerWeb.{
    BookActions,
    BookFormat,
    DashboardData,
    ReadingLogFormat,
    ReadingLogSession
  }

  @status_filters [
    all: "All",
    in_progress: "Reading",
    want_to_read: "Queued",
    finished: "Finished",
    abandoned: "Abandoned"
  ]

  @impl true
  def mount(_params, session, socket) do
    case ReadingLogSession.resolve_or_nil(session) do
      nil ->
        {:ok,
         socket
         |> put_flash(:info, "Choose a reading log to continue.")
         |> push_navigate(to: ~p"/")}

      reading_log ->
        {:ok,
         socket
         |> assign(:page_title, reading_log.name)
         |> assign(:search_query, "")
         |> assign(:search_form, to_form(%{"query" => ""}, as: :search))
         |> assign(:status_filter, :all)
         |> assign(:difficulty_filter, :all)
         |> assign(:page_index, 0)
         |> assign(:page_size, 4)
         |> assign(:selected_book, nil)
         |> assign(:inspector_open?, true)
         |> assign(:inspector_tab, "details")
         |> assign(:progress_open?, false)
         |> assign(:status_filters, @status_filters)
         |> assign_dashboard(reading_log)}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :progress_open?, params["view"] == "progress")

    socket =
      case Enum.find(socket.assigns.all_books, &(&1.id == params["book"])) do
        nil ->
          socket

        book ->
          index = Enum.find_index(socket.assigns.all_books, &(&1.id == book.id))

          socket
          |> assign(
            selected_book: book,
            inspector_open?: true,
            page_index: div(index, socket.assigns.page_size)
          )
          |> apply_book_filters()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_books", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     socket
     |> assign(
       search_query: String.trim(query),
       search_form: to_form(%{"query" => query}, as: :search),
       page_index: 0
     )
     |> apply_book_filters()}
  end

  def handle_event("filter_books", %{"status" => status}, socket) do
    status =
      Enum.find_value(@status_filters, :all, fn {key, _} ->
        if Atom.to_string(key) == status, do: key
      end)

    {:noreply, socket |> assign(status_filter: status, page_index: 0) |> apply_book_filters()}
  end

  def handle_event("filter_difficulty", %{"difficulty" => difficulty}, socket) do
    difficulty = DashboardData.resolve_difficulty(difficulty, socket.assigns.difficulty_options)

    {:noreply,
     socket |> assign(difficulty_filter: difficulty, page_index: 0) |> apply_book_filters()}
  end

  def handle_event("select_book", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.all_books, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      book ->
        {:noreply,
         socket
         |> assign(selected_book: book, inspector_open?: true, inspector_tab: "details")
         |> apply_book_filters()}
    end
  end

  def handle_event("inspector_tab", %{"tab" => tab}, socket)
      when tab in ~w(details notes metadata) do
    {:noreply, assign(socket, :inspector_tab, tab)}
  end

  def handle_event("toggle_inspector", _params, socket),
    do: {:noreply, assign(socket, :inspector_open?, !socket.assigns.inspector_open?)}

  def handle_event("close_inspector", _params, socket),
    do: {:noreply, assign(socket, :inspector_open?, false)}

  def handle_event("paginate", %{"direction" => direction}, socket)
      when direction in ~w(previous next) do
    offset = if direction == "next", do: 1, else: -1

    {:noreply,
     socket |> assign(:page_index, socket.assigns.page_index + offset) |> apply_book_filters()}
  end

  def handle_event("resize_books", %{"rows" => rows}, socket) when is_integer(rows) do
    rows = min(max(rows, 1), 30)
    # Keep the same first visible book when the viewport changes size.
    index = div(socket.assigns.page_index * socket.assigns.page_size, rows)
    {:noreply, socket |> assign(page_size: rows, page_index: index) |> apply_book_filters()}
  end

  def handle_event("update_status", %{"action" => action, "book_id" => id}, socket)
      when action in ~w(start finish abandon reopen) do
    with %{} = book <- Enum.find(socket.assigns.all_books, &(&1.id == id)),
         {:ok, updated_book} <- update_book_status(book, action) do
      {:noreply,
       socket
       |> assign(:selected_book, updated_book)
       |> put_flash(:info, BookFormat.status_message(updated_book, action))
       |> assign_dashboard(socket.assigns.reading_log)}
    else
      _ -> {:noreply, put_flash(socket, :error, "We couldn't update this book. Try again.")}
    end
  end

  defp assign_dashboard(socket, reading_log) do
    books =
      Library.list_books!(
        query: [
          filter: [reading_log_id: reading_log.id],
          sort: [added_on: :desc, inserted_at: :desc]
        ]
      )
      |> Enum.sort_by(&status_rank(&1.status))

    socket
    |> assign(
      reading_log: reading_log,
      all_books: books,
      difficulty_options: DashboardData.difficulty_options(books),
      summary: DashboardData.summarize(books, reading_log.word_goal),
      status_counts: Enum.frequencies_by(books, & &1.status)
    )
    |> apply_book_filters()
  end

  defp apply_book_filters(socket) do
    books =
      DashboardData.filter(
        socket.assigns.all_books,
        socket.assigns.search_query,
        socket.assigns.status_filter,
        socket.assigns.difficulty_filter
      )

    count = length(books)
    pages = max(ceil(count / socket.assigns.page_size), 1)
    index = socket.assigns.page_index |> max(0) |> min(pages - 1)
    page = Enum.slice(books, index * socket.assigns.page_size, socket.assigns.page_size)
    selected_id = socket.assigns.selected_book && socket.assigns.selected_book.id
    selected = Enum.find(page, &(&1.id == selected_id)) || List.first(page)

    socket
    |> assign(
      page_index: index,
      page_count: pages,
      matching_book_count: count,
      selected_book: selected,
      first_book_index: if(count == 0, do: 0, else: index * socket.assigns.page_size + 1),
      last_book_index: min((index + 1) * socket.assigns.page_size, count),
      filtering?:
        socket.assigns.search_query != "" || socket.assigns.status_filter != :all ||
          socket.assigns.difficulty_filter != :all
    )
    |> stream(:books, page, reset: true)
  end

  defp status_rank(:in_progress), do: 0
  defp status_rank(:want_to_read), do: 1
  defp status_rank(:finished), do: 2
  defp status_rank(:abandoned), do: 3
  defp status_actions(:want_to_read), do: ~w(start finish)
  defp status_actions(:in_progress), do: ~w(finish abandon)
  defp status_actions(_), do: ~w(reopen)
  defp update_book_status(book, "start"), do: Library.start_book(book)
  defp update_book_status(book, "finish"), do: Library.finish_book(book)
  defp update_book_status(book, "abandon"), do: Library.abandon_book(book)
  defp update_book_status(book, "reopen"), do: Library.reopen_book(book)
  defp display_date(nil), do: "—"
  defp display_date(date), do: Calendar.strftime(date, "%b %-d, %Y")
  defp display_number(nil), do: "—"
  defp display_number(number), do: BookFormat.number(number)
end
