defmodule CiBookTrackerWeb.HomeLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogFormat

  @impl true
  def mount(_params, session, socket) do
    case auto_open_reading_log(session) do
      {:ok, _reading_log} ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}

      _no_auto_open ->
        reading_logs = Library.list_reading_logs!(query: [sort: [inserted_at: :asc]])

        {:ok,
         socket
         |> assign(:page_title, "Reading logs")
         |> assign(:reading_logs, reading_logs)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="reading-log-selector" class="space-y-8">
        <header class="rounded-[2rem] border border-amber-200 bg-white p-7 shadow-sm shadow-amber-100 sm:p-10">
          <div class="grid size-14 place-items-center rounded-2xl bg-amber-100 text-amber-800">
            <.icon name="hero-language" class="size-7" />
          </div>
          <p class="mt-7 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Local reading tracker
          </p>
          <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Choose a reading log
          </h1>
          <p class="mt-4 max-w-xl text-base leading-7 text-slate-600">
            Open a language shelf or create a new one. Every log and book stays on this device.
          </p>
        </header>

        <.button
          id="create-reading-log"
          navigate={~p"/reading-logs/new"}
          variant="primary"
          class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-amber-700 px-6 text-base font-semibold text-white shadow-lg shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
        >
          <.icon name="hero-plus" class="size-5" /> Create New Reading Log
        </.button>

        <div
          :if={@reading_logs == []}
          id="empty-reading-logs"
          class="rounded-3xl border border-dashed border-slate-300 px-6 py-10 text-center"
        >
          <p class="font-semibold text-slate-900">No reading logs yet</p>
          <p class="mt-2 text-sm leading-6 text-slate-500">
            Create your first log to start tracking books and reading goals.
          </p>
        </div>

        <div :if={@reading_logs != []} id="reading-log-list" class="space-y-4">
          <article
            :for={reading_log <- @reading_logs}
            id={"reading-log-#{reading_log.id}"}
            class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/50 transition hover:border-amber-300 hover:shadow-md sm:p-6"
          >
            <div class="flex items-start gap-4">
              <div class="grid size-12 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
                <.icon name="hero-book-open" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-xs font-semibold uppercase tracking-[0.16em] text-amber-700">
                  {ReadingLogFormat.language_name(reading_log.language_code)}
                  <span class="normal-case tracking-normal text-amber-700/70">
                    ({reading_log.language_code})
                  </span>
                </p>
                <h2 class="mt-1 text-xl font-semibold tracking-tight text-slate-950">
                  {reading_log.name}
                </h2>
                <p :if={reading_log.word_goal} class="mt-2 text-sm text-slate-500">
                  Goal: {ReadingLogFormat.format_word_goal(reading_log.word_goal)}
                </p>
                <p :if={is_nil(reading_log.word_goal)} class="mt-2 text-sm text-slate-500">
                  No word goal set
                </p>
              </div>
            </div>

            <.link
              id={"open-reading-log-#{reading_log.id}"}
              href={~p"/reading-logs/#{reading_log.id}/open"}
              class="mt-5 inline-flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
            >
              Open <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp auto_open_reading_log(%{"auto_open_reading_log_id" => id}) do
    Library.get_reading_log(id)
  end

  defp auto_open_reading_log(_session), do: :disabled
end
