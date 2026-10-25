defmodule CiBookTrackerWeb.HomeLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogFormat

  @impl true
  def mount(params, session, socket) do
    auto_open = if params["logs"] == "all", do: :disabled, else: auto_open_reading_log(session)

    case auto_open do
      {:ok, _reading_log} ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}

      _no_auto_open ->
        reading_logs = Library.list_reading_logs!(query: [sort: [inserted_at: :asc]])

        {:ok,
         socket
         |> assign(:page_title, "Reading logs")
         |> assign(:delete_reading_log, nil)
         |> assign(:reading_logs, reading_logs)}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    reading_log = Enum.find(socket.assigns.reading_logs, &(&1.id == id))
    {:noreply, assign(socket, :delete_reading_log, reading_log)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_reading_log, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} workspace={@workspace}>
      <section id="reading-log-selector" class="log-selector">
        <header class="log-selector-heading">
          <p class="workspace-eyebrow">Your workspace</p>
          <h1>Reading logs</h1>
          <p class="workspace-muted">Choose a language, pick up a book, and keep going.</p>
        </header>

        <section id="existing-reading-logs">
          <div class="log-section-heading">
            <h2>Continue reading</h2>
            <span class="workspace-muted">{length(@reading_logs)} logs</span>
          </div>
          <div :if={@reading_logs == []} id="empty-reading-logs" class="log-empty">
            <p>No reading logs yet</p>
            <p class="workspace-muted">
              Create your first log to start tracking books and reading goals.
            </p>
          </div>
          <div :if={@reading_logs != []} id="reading-log-list" class="log-list">
            <article
              :for={reading_log <- @reading_logs}
              id={"reading-log-#{reading_log.id}"}
              class="log-row"
            >
              <span class="log-language-badge" aria-hidden="true">{String.upcase(
                reading_log.language_code
              )}</span>
              <div class="log-row-description">
                <h3>{reading_log.name}</h3>
                <p class="workspace-muted">
                  {ReadingLogFormat.language_name(reading_log.language_code)} ({reading_log.language_code})
                  <span aria-hidden="true" class="mx-2">·</span>
                  <%= if reading_log.word_goal do %>
                    Goal: {ReadingLogFormat.format_word_goal(reading_log.word_goal)}
                  <% else %>
                    No word goal set
                  <% end %>
                </p>
              </div>
              <div class="log-row-actions">
                <.link
                  id={"open-reading-log-#{reading_log.id}"}
                  href={~p"/reading-logs/#{reading_log.id}/open"}
                  class="workspace-button"
                >
                  Open <.icon name="hero-arrow-right" class="size-4" />
                </.link>
                <.link
                  id={"edit-reading-log-#{reading_log.id}"}
                  navigate={~p"/reading-logs/#{reading_log.id}/edit"}
                  class="workspace-icon-button"
                  aria-label={"Edit #{reading_log.name}"}
                >
                  <.icon name="hero-pencil-square" class="size-4" /><span class="sr-only">Edit</span>
                </.link>
                <button
                  id={"delete-reading-log-#{reading_log.id}"}
                  type="button"
                  phx-click="confirm_delete"
                  phx-value-id={reading_log.id}
                  class="workspace-icon-button log-delete"
                  aria-label={"Delete #{reading_log.name}"}
                >
                  <.icon name="hero-trash" class="size-4" /><span class="sr-only">Delete</span>
                </button>
              </div>
            </article>
          </div>
        </section>

        <section id="new-reading-log" class="log-new">
          <header>
            <h2>Create a new reading log</h2>
            <p class="workspace-muted">A fresh space for another language or reading goal.</p>
          </header>
          <div class="log-new-actions">
            <.link
              id="create-reading-log"
              navigate={~p"/reading-logs/new"}
              class="workspace-button"
            >
              <.icon name="hero-plus" class="size-4" /> Create New Reading Log
            </.link>
            <.link
              id="restore-backup"
              navigate={~p"/settings/restore"}
              class="workspace-button"
            >
              <.icon name="hero-arrow-up-tray" class="size-4" /> Restore from backup
            </.link>
          </div>
        </section>
      </section>

      <div
        :if={@delete_reading_log}
        id="delete-reading-log-confirmation"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-reading-log-title"
        class="fixed inset-0 z-50 grid place-items-end bg-slate-950/50 p-4 backdrop-blur-sm sm:place-items-center"
      >
        <section class="w-full max-w-md rounded-[2rem] bg-white p-6 shadow-2xl sm:p-8">
          <div class="grid size-12 place-items-center rounded-2xl bg-rose-100 text-rose-700">
            <.icon name="hero-exclamation-triangle" class="size-6" />
          </div>
          <h2
            id="delete-reading-log-title"
            class="mt-5 text-2xl font-semibold tracking-tight text-slate-950"
          >
            Delete {@delete_reading_log.name}?
          </h2>
          <p class="mt-3 text-sm leading-6 text-slate-600">
            This permanently deletes this reading log and every book in it. This cannot be undone.
          </p>

          <div class="mt-7 grid gap-3">
            <.link
              id="confirm-delete-reading-log"
              href={~p"/reading-logs/#{@delete_reading_log.id}"}
              method="delete"
              class="inline-flex min-h-14 items-center justify-center gap-2 rounded-2xl bg-rose-700 px-5 text-sm font-semibold text-white transition hover:bg-rose-800 focus:outline-none focus:ring-2 focus:ring-rose-500 focus:ring-offset-2"
            >
              <.icon name="hero-trash" class="size-4" /> Delete Reading Log
            </.link>
            <button
              id="cancel-delete-reading-log"
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

  defp auto_open_reading_log(%{"auto_open_reading_log_id" => id}) do
    Library.get_reading_log(id)
  end

  defp auto_open_reading_log(_session), do: :disabled
end
