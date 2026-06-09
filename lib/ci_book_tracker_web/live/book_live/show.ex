defmodule CiBookTrackerWeb.BookLive.Show do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.BookFormat

  @impl true
  def mount(%{"id" => id}, session, socket) do
    with {:ok, reading_log} <- active_reading_log(session),
         {:ok, %{reading_log_id: reading_log_id} = book} <- Library.get_book(id),
         true <- reading_log_id == reading_log.id do
      {:ok,
       socket
       |> assign(:page_title, book.title)
       |> assign(:reading_log, reading_log)
       |> assign(:book, book)
       |> assign(:confirm_delete?, false)}
    else
      _missing ->
        {:ok,
         socket
         |> put_flash(:error, "That book isn't available in the active reading log.")
         |> push_navigate(to: fallback_path(session))}
    end
  end

  @impl true
  def handle_event("update_status", %{"action" => action}, socket)
      when action in ~w(start finish abandon) do
    case update_book_status(socket.assigns.book, action) do
      {:ok, book} ->
        {:noreply,
         socket
         |> assign(:book, book)
         |> put_flash(:info, BookFormat.status_message(book, action))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "We couldn't update this book. Try again.")}
    end
  end

  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete?, true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete?, false)}
  end

  def handle_event("delete", _params, socket) do
    case Library.delete_book(socket.assigns.book) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "#{socket.assigns.book.title} was deleted.")
         |> push_navigate(to: ~p"/dashboard")}

      {:ok, _book} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{socket.assigns.book.title} was deleted.")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:confirm_delete?, false)
         |> put_flash(:error, "We couldn't delete this book. Try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="book-detail" class="space-y-7">
        <header>
          <.link
            id="back-to-dashboard"
            navigate={~p"/dashboard"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to dashboard
          </.link>

          <div class="mt-5 flex items-start gap-5 sm:gap-7">
            <.book_cover
              id="book-detail-cover"
              title={@book.title}
              cover_url={@book.cover_url}
              cover_provider={@book.cover_provider}
              cover_id={@book.cover_id}
              size={:detail}
            />

            <div class="min-w-0 flex-1 pt-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class={[
                  "rounded-full px-3 py-1 text-xs font-semibold",
                  BookFormat.status_class(@book.status)
                ]}>
                  {BookFormat.status_label(@book.status)}
                </span>
                <span :if={@book.difficulty_label} class="text-sm font-medium text-slate-500">
                  {@book.difficulty_label}
                </span>
              </div>

              <p class="mt-4 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
                {@reading_log.name}
              </p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
                {@book.title}
              </h1>
              <p class="mt-2 text-base leading-7 text-slate-600 sm:text-lg">
                {@book.author || "Author not set"}
              </p>
            </div>
          </div>
        </header>

        <section
          :if={status_actions(@book.status) != []}
          id="book-status-actions"
          class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-7"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">
            Reading status
          </p>
          <div class="mt-4 grid gap-3 sm:grid-cols-2">
            <button
              :for={{action, label, icon, button_class} <- status_actions(@book.status)}
              id={"book-#{action}"}
              type="button"
              phx-click="update_status"
              phx-value-action={action}
              phx-disable-with={"#{label}..."}
              class={[
                "inline-flex min-h-14 items-center justify-center gap-2 rounded-2xl px-5 text-sm font-semibold transition hover:-translate-y-0.5 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0 disabled:translate-y-0 disabled:cursor-wait disabled:opacity-60",
                button_class
              ]}
            >
              <.icon name={icon} class="size-4" /> {label}
            </button>
          </div>
        </section>

        <section
          id="book-details"
          class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-7"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-amber-700">
                Book details
              </p>
              <h2 class="mt-1 text-xl font-semibold tracking-tight text-slate-950">
                At a glance
              </h2>
            </div>
            <div class="grid gap-2 sm:grid-cols-2">
              <.link
                id="find-metadata"
                navigate={~p"/books/#{@book.id}/edit?metadata=refresh"}
                class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-amber-300 bg-amber-50 px-4 text-sm font-semibold text-amber-900 transition hover:bg-amber-100 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
              >
                <.icon name="hero-arrow-path" class="size-4" /> Refresh Metadata
              </.link>
              <.link
                id="edit-book"
                navigate={~p"/books/#{@book.id}/edit"}
                class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-slate-200 px-4 text-sm font-semibold text-slate-700 transition hover:border-amber-300 hover:bg-amber-50 hover:text-amber-900 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
              >
                <.icon name="hero-pencil-square" class="size-4" /> Edit Book
              </.link>
            </div>
          </div>

          <dl class="mt-6 divide-y divide-slate-100">
            <.detail_row label="Status" value={BookFormat.status_label(@book.status)} />
            <.detail_row label="Difficulty" value={@book.difficulty_label} />
            <.detail_row label="Page count" value={format_pages(@book.page_count)} />
            <.detail_row
              label="Estimated total words"
              value={BookFormat.words(@book.estimated_words)}
            />
            <.detail_row label="Added" value={BookFormat.date(@book.added_on)} />
            <.detail_row label="Started" value={BookFormat.date(@book.started_on)} />
            <.detail_row label="Finished" value={BookFormat.date(@book.finished_on)} />
          </dl>
        </section>

        <section
          id="book-notes"
          class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-7"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.16em] text-amber-700">Notes</p>
          <p class="mt-3 whitespace-pre-wrap text-base leading-7 text-slate-700">
            {@book.notes || "No notes yet."}
          </p>
        </section>

        <section
          id="book-danger-zone"
          class="rounded-[2rem] border border-rose-200 bg-rose-50/50 p-5 sm:p-7"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.16em] text-rose-700">
            Danger zone
          </p>
          <h2 class="mt-2 text-xl font-semibold tracking-tight text-slate-950">Delete this book</h2>
          <p class="mt-2 text-sm leading-6 text-slate-600">
            Permanently remove this book and its reading history. This cannot be undone.
          </p>
          <button
            id="delete-book"
            type="button"
            phx-click="confirm_delete"
            class="mt-5 inline-flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl border border-rose-300 bg-white px-5 text-sm font-semibold text-rose-700 transition hover:border-rose-400 hover:bg-rose-100 focus:outline-none focus:ring-2 focus:ring-rose-500 focus:ring-offset-2"
          >
            <.icon name="hero-trash" class="size-4" /> Delete Book
          </button>
        </section>
      </section>

      <div
        :if={@confirm_delete?}
        id="delete-book-confirmation"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-book-title"
        class="fixed inset-0 z-50 grid place-items-end bg-slate-950/50 p-4 backdrop-blur-sm sm:place-items-center"
      >
        <section class="w-full max-w-md rounded-[2rem] bg-white p-6 shadow-2xl sm:p-8">
          <div class="grid size-12 place-items-center rounded-2xl bg-rose-100 text-rose-700">
            <.icon name="hero-exclamation-triangle" class="size-6" />
          </div>
          <h2 id="delete-book-title" class="mt-5 text-2xl font-semibold tracking-tight text-slate-950">
            Delete “{@book.title}”?
          </h2>
          <p class="mt-3 text-sm leading-6 text-slate-600">
            This permanently deletes the book and its reading history. This cannot be undone.
          </p>
          <div class="mt-7 grid gap-3">
            <button
              id="confirm-delete-book"
              type="button"
              phx-click="delete"
              phx-disable-with="Deleting..."
              class="inline-flex min-h-14 items-center justify-center gap-2 rounded-2xl bg-rose-700 px-5 text-sm font-semibold text-white transition hover:bg-rose-800 focus:outline-none focus:ring-2 focus:ring-rose-500 focus:ring-offset-2 disabled:cursor-wait disabled:opacity-60"
            >
              <.icon name="hero-trash" class="size-4" /> Delete Book
            </button>
            <button
              id="cancel-delete-book"
              type="button"
              phx-click="cancel_delete"
              class="inline-flex min-h-14 items-center justify-center rounded-2xl border border-slate-200 px-5 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
            >
              Cancel
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp detail_row(assigns) do
    ~H"""
    <div class="grid gap-1 py-4 sm:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)] sm:gap-6">
      <dt class="text-sm font-medium text-slate-500">{@label}</dt>
      <dd class="text-base font-semibold text-slate-900 sm:text-right">{@value || "Not set"}</dd>
    </div>
    """
  end

  defp active_reading_log(session) do
    id = session["active_reading_log_id"] || session["auto_open_reading_log_id"]

    case id && Library.get_reading_log(id) do
      {:ok, reading_log} -> {:ok, reading_log}
      _missing -> {:error, :not_found}
    end
  end

  defp fallback_path(session) do
    if session["active_reading_log_id"] || session["auto_open_reading_log_id"],
      do: ~p"/dashboard",
      else: ~p"/"
  end

  defp update_book_status(book, "start"), do: Library.start_book(book)
  defp update_book_status(book, "finish"), do: Library.finish_book(book)
  defp update_book_status(book, "abandon"), do: Library.abandon_book(book)

  defp status_actions(:want_to_read) do
    [
      {"start", "Start", "hero-play", "bg-sky-700 text-white hover:bg-sky-800"},
      {"finish", "Finish", "hero-check", "bg-emerald-700 text-white hover:bg-emerald-800"},
      {"abandon", "Abandon", "hero-archive-box",
       "sm:col-span-2 bg-slate-200 text-slate-800 hover:bg-slate-300"}
    ]
  end

  defp status_actions(:in_progress) do
    [
      {"finish", "Finish", "hero-check", "bg-emerald-700 text-white hover:bg-emerald-800"},
      {"abandon", "Abandon", "hero-archive-box", "bg-slate-200 text-slate-800 hover:bg-slate-300"}
    ]
  end

  defp status_actions(status) when status in [:finished, :abandoned], do: []

  defp format_pages(nil), do: nil
  defp format_pages(page_count), do: BookFormat.number(page_count)
end
