defmodule CiBookTrackerWeb.HomeLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library

  @status_groups [
    {:in_progress, "In progress", "hero-book-open", "bg-sky-100 text-sky-800"},
    {:want_to_read, "Want to read", "hero-bookmark", "bg-amber-100 text-amber-800"},
    {:finished, "Finished", "hero-check-circle", "bg-emerald-100 text-emerald-800"},
    {:abandoned, "Abandoned", "hero-archive-box", "bg-slate-200 text-slate-700"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    reading_log =
      Library.list_reading_logs!(query: [sort: [inserted_at: :asc], limit: 1])
      |> List.first()

    {:ok,
     socket
     |> assign(:page_title, "Your reading")
     |> assign_dashboard(reading_log)}
  end

  @impl true
  def handle_event("create_reading_log", _params, socket) do
    {:noreply, put_flash(socket, :info, "Reading log setup is the next feature.")}
  end

  def handle_event("add_book", _params, socket) do
    {:noreply, put_flash(socket, :info, "Manual book entry is the next feature.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section :if={is_nil(@reading_log)} id="welcome" class="space-y-8">
        <div class="rounded-[2rem] border border-amber-200 bg-white p-7 shadow-sm shadow-amber-100 sm:p-10">
          <div class="grid size-14 place-items-center rounded-2xl bg-amber-100 text-amber-800">
            <.icon name="hero-language" class="size-7" />
          </div>
          <p class="mt-7 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Your reading journey
          </p>
          <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Read more in the language you are learning.
          </h1>
          <p class="mt-4 max-w-xl text-base leading-7 text-slate-600">
            Create one local reading log, set a word goal, and keep every book and milestone
            together on this device.
          </p>
        </div>

        <.button
          id="create-reading-log"
          phx-click="create_reading_log"
          variant="primary"
          class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-amber-700 px-6 text-base font-semibold text-white shadow-lg shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
        >
          <.icon name="hero-plus" class="size-5" /> Create Reading Log
        </.button>
      </section>

      <section :if={@reading_log} id="dashboard" class="space-y-8">
        <header class="space-y-3">
          <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            <span>{@reading_log.language_code}</span>
            <span aria-hidden="true" class="size-1 rounded-full bg-amber-400"></span>
            <span>Reading dashboard</span>
          </div>
          <h1 class="text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            {@reading_log.name}
          </h1>
          <p class="text-base leading-7 text-slate-600">
            Keep moving toward your {format_number(@reading_log.word_goal)} word goal.
          </p>
        </header>

        <div id="summary-cards" class="space-y-3">
          <.summary_card
            id="summary-books-finished"
            label="Books finished"
            value={@summary.books_finished}
            icon="hero-check-circle"
            icon_class="bg-emerald-100 text-emerald-800"
          />
          <.summary_card
            id="summary-books-in-progress"
            label="Books in progress"
            value={@summary.books_in_progress}
            icon="hero-book-open"
            icon_class="bg-sky-100 text-sky-800"
          />
          <.summary_card
            id="words-completed"
            label="Estimated words completed"
            value={format_number(@summary.words_completed)}
            icon="hero-document-text"
            icon_class="bg-violet-100 text-violet-800"
          />

          <article
            id="goal-progress"
            class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/50"
          >
            <div class="flex items-center gap-4">
              <div class="grid size-11 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
                <.icon name="hero-chart-bar" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex items-end justify-between gap-4">
                  <p class="text-sm font-medium text-slate-600">Goal progress</p>
                  <p class="text-2xl font-semibold tracking-tight text-slate-950">
                    {@summary.goal_progress}%
                  </p>
                </div>
                <div
                  class="mt-3 h-2.5 overflow-hidden rounded-full bg-slate-100"
                  role="progressbar"
                  aria-label="Reading goal progress"
                  aria-valuemin="0"
                  aria-valuemax="100"
                  aria-valuenow={@summary.goal_progress}
                >
                  <div
                    class="h-full rounded-full bg-amber-600 transition-[width] duration-500"
                    style={"width: #{min(@summary.goal_progress, 100)}%"}
                  >
                  </div>
                </div>
              </div>
            </div>
          </article>
        </div>

        <.button
          id="add-book"
          phx-click="add_book"
          variant="primary"
          class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-slate-950 px-6 text-base font-semibold text-white shadow-lg shadow-slate-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
        >
          <.icon name="hero-plus" class="size-5" /> Add Book
        </.button>

        <div id="book-groups" class="space-y-7">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
              Your books
            </p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
              Reading shelf
            </h2>
          </div>

          <section
            :for={{status, label, icon, icon_class} <- @status_groups}
            id={"books-#{status}"}
            class="space-y-3"
          >
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <span class={["grid size-9 place-items-center rounded-xl", icon_class]}>
                  <.icon name={icon} class="size-4" />
                </span>
                <h3 class="font-semibold text-slate-900">{label}</h3>
              </div>
              <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-600">
                {length(@books_by_status[status])}
              </span>
            </div>

            <div
              :if={@books_by_status[status] == []}
              class="rounded-2xl border border-dashed border-slate-300 px-5 py-6 text-center"
            >
              <p class="text-sm text-slate-500">No books here yet.</p>
            </div>

            <div :if={@books_by_status[status] != []} class="space-y-3">
              <.book_card :for={book <- @books_by_status[status]} book={book} />
            </div>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :icon_class, :string, required: true

  defp summary_card(assigns) do
    ~H"""
    <article
      id={@id}
      class="flex items-center gap-4 rounded-3xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/50"
    >
      <div class={["grid size-11 shrink-0 place-items-center rounded-2xl", @icon_class]}>
        <.icon name={@icon} class="size-5" />
      </div>
      <div>
        <p class="text-sm font-medium text-slate-600">{@label}</p>
        <p class="mt-0.5 text-2xl font-semibold tracking-tight text-slate-950">{@value}</p>
      </div>
    </article>
    """
  end

  attr :book, CiBookTracker.Library.Book, required: true

  defp book_card(assigns) do
    ~H"""
    <article
      id={"book-#{@book.id}"}
      class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/50 transition hover:border-amber-300 hover:shadow-md"
    >
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <h4 class="font-semibold leading-6 text-slate-950">{@book.title}</h4>
          <p :if={@book.author} class="mt-1 text-sm text-slate-500">{@book.author}</p>
        </div>
        <span
          :if={@book.difficulty_label}
          class="shrink-0 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-800"
        >
          {@book.difficulty_label}
        </span>
      </div>
      <div
        :if={@book.page_count || @book.estimated_words}
        class="mt-4 flex flex-wrap gap-x-4 gap-y-2 border-t border-slate-100 pt-4 text-xs font-medium text-slate-500"
      >
        <span :if={@book.page_count} class="flex items-center gap-1.5">
          <.icon name="hero-document" class="size-4" />
          {@book.page_count} pages
        </span>
        <span :if={@book.estimated_words} class="flex items-center gap-1.5">
          <.icon name="hero-bars-3-bottom-left" class="size-4" />
          {format_number(@book.estimated_words)} words
        </span>
      </div>
    </article>
    """
  end

  defp assign_dashboard(socket, nil) do
    assign(socket,
      reading_log: nil,
      books_by_status: empty_books_by_status(),
      status_groups: @status_groups,
      summary: empty_summary()
    )
  end

  defp assign_dashboard(socket, reading_log) do
    books =
      Library.list_books!(
        query: [
          filter: [reading_log_id: reading_log.id],
          sort: [added_on: :desc, inserted_at: :desc]
        ]
      )

    assign(socket,
      reading_log: reading_log,
      books_by_status:
        Map.merge(empty_books_by_status(), Enum.group_by(books, & &1.status, & &1)),
      status_groups: @status_groups,
      summary: summarize(books, reading_log.word_goal)
    )
  end

  defp summarize(books, word_goal) do
    books_finished = Enum.count(books, &(&1.status == :finished))
    books_in_progress = Enum.count(books, &(&1.status == :in_progress))

    words_completed =
      books
      |> Enum.filter(&(&1.status == :finished))
      |> Enum.map(&(&1.estimated_words || 0))
      |> Enum.sum()

    %{
      books_finished: books_finished,
      books_in_progress: books_in_progress,
      words_completed: words_completed,
      goal_progress: min(round(words_completed / word_goal * 100), 100)
    }
  end

  defp empty_summary do
    %{books_finished: 0, books_in_progress: 0, words_completed: 0, goal_progress: 0}
  end

  defp empty_books_by_status do
    Map.new(@status_groups, fn {status, _label, _icon, _class} -> {status, []} end)
  end

  defp format_number(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end
