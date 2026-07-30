defmodule CiBookTrackerWeb.BackupLive do
  use CiBookTrackerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Portable backup")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="database-backup" class="space-y-7">
        <header>
          <.link
            navigate={~p"/"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to reading logs
          </.link>

          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Settings
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Portable backup
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            Download a portable copy of your database and locally stored cover art.
          </p>
        </header>

        <section class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8">
          <div class="flex items-start gap-4">
            <span class="grid size-12 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
              <.icon name="hero-circle-stack" class="size-6" />
            </span>
            <div>
              <h2 class="text-xl font-semibold tracking-tight text-slate-950">
                Export your data
              </h2>
              <p class="mt-2 text-sm leading-6 text-slate-600">
                This downloads a ZIP archive containing the complete SQLite database and every
                locally stored book cover.
              </p>
            </div>
          </div>

          <.link
            id="export-database"
            href={~p"/backup/database"}
            class="mt-7 flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-slate-950 px-6 text-base font-semibold text-white shadow-lg shadow-slate-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
          >
            <.icon name="hero-arrow-down-tray" class="size-5" /> Export Backup
          </.link>

          <p class="mt-4 text-xs leading-5 text-slate-500">
            Store the downloaded file somewhere separate from this device. You can restore it later
            from Settings.
          </p>
        </section>
      </section>
    </Layouts.app>
    """
  end
end
