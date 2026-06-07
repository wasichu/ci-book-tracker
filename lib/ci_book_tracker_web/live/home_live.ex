defmodule CiBookTrackerWeb.HomeLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Your reading")
     |> assign(:reading_logs, Library.list_reading_logs!())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-7">
        <div class="space-y-3">
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">Your library</p>
          <h1 class="max-w-xl text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Make your next page count.
          </h1>
          <p class="max-w-xl text-base leading-7 text-slate-600">
            Track books, reading progress, and vocabulary goals for every language you study.
          </p>
        </div>

        <div
          :if={@reading_logs == []}
          id="empty-reading-logs"
          class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm shadow-slate-200/60 sm:p-8"
        >
          <div class="grid size-12 place-items-center rounded-2xl bg-amber-100 text-amber-800">
            <.icon name="hero-language" class="size-6" />
          </div>
          <h2 class="mt-5 text-lg font-semibold tracking-tight">Start with a language</h2>
          <p class="mt-2 max-w-md text-sm leading-6 text-slate-600">
            Your reading logs will appear here. The next feature will add the manual setup flow.
          </p>
        </div>

        <div :if={@reading_logs != []} id="reading-logs" class="grid gap-3 sm:grid-cols-2">
          <article
            :for={reading_log <- @reading_logs}
            class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-md"
          >
            <p class="text-xs font-semibold uppercase tracking-wider text-amber-700">
              {reading_log.language_code}
            </p>
            <h2 class="mt-2 text-lg font-semibold tracking-tight">{reading_log.name}</h2>
            <p class="mt-1 text-sm text-slate-500">
              {reading_log.word_goal} word goal
            </p>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
