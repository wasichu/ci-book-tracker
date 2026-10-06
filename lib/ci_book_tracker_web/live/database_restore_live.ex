defmodule CiBookTrackerWeb.DatabaseRestoreLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.DatabaseRestore
  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogSession

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Restore backup")
     |> assign(:show_export_warning, open_log_has_books?(session))
     |> assign(:staged_path, nil)
     |> assign(:uploaded_name, nil)
     |> assign(:validation_error, nil)
     |> assign(:restore_result, nil)
     |> allow_upload(:database,
       accept: [".zip", ".db", ".sqlite", ".sqlite3"],
       max_entries: 1,
       auto_upload: true,
       progress: &handle_upload_progress/3,
       max_file_size: 250_000_000
     )}
  end

  @impl true
  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_restore", _params, socket) do
    cleanup_staged_file(socket.assigns.staged_path)

    {:noreply,
     socket
     |> assign(:staged_path, nil)
     |> assign(:uploaded_name, nil)
     |> assign(:validation_error, nil)}
  end

  def handle_event("restore_database", _params, %{assigns: %{staged_path: staged}} = socket)
      when not is_nil(staged) do
    case DatabaseRestore.restore(staged) do
      {:ok, result} ->
        cleanup_staged_file(staged)

        {:noreply,
         socket
         |> assign(:staged_path, nil)
         |> assign(:uploaded_name, nil)
         |> assign(:restore_result, result)
         |> assign(:validation_error, nil)}

      {:error, reason} ->
        {:noreply, assign(socket, :validation_error, DatabaseRestore.error_message(reason))}
    end
  end

  def handle_event("restore_database", _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    cleanup_staged_file(socket.assigns[:staged_path])
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="database-restore-page" class="space-y-7">
        <header>
          <.link
            navigate={~p"/settings"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to settings
          </.link>
          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-rose-700">
            Destructive action
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Restore backup
          </h1>
          <p class="mt-3 max-w-2xl text-base leading-7 text-slate-600">
            Replace this installation with a previously exported CI Book Tracker backup.
          </p>
        </header>

        <section
          :if={is_nil(@restore_result) && (is_nil(@staged_path) || !@show_export_warning)}
          id="restore-upload"
          class="rounded-[2rem] border border-rose-200 bg-white p-5 shadow-sm shadow-rose-100/60 sm:p-7"
        >
          <div
            :if={@show_export_warning}
            id="restore-export-warning"
            class="rounded-2xl bg-amber-50 p-4 text-sm leading-6 text-amber-950"
          >
            <p class="font-semibold">Export your current database before continuing.</p>
            <p class="mt-1">
              The app also creates an automatic safety backup immediately before restoring.
            </p>
            <.link
              href={~p"/backup/database"}
              class="mt-3 inline-flex min-h-11 items-center gap-2 font-semibold text-amber-900 underline decoration-amber-400 underline-offset-4"
            >
              <.icon name="hero-arrow-down-tray" class="size-4" /> Export current database
            </.link>
          </div>

          <.form
            :if={is_nil(@staged_path)}
            for={to_form(%{}, as: :restore)}
            id="database-restore-form"
            phx-change="validate_upload"
            class="mt-6 space-y-4"
          >
            <label
              for={@uploads.database.ref}
              class="flex min-h-36 cursor-pointer flex-col items-center justify-center rounded-2xl border-2 border-dashed border-slate-300 bg-slate-50 px-5 text-center transition hover:border-rose-400 hover:bg-rose-50/50"
            >
              <.icon name="hero-circle-stack" class="size-7 text-slate-500" />
              <span class="mt-3 font-semibold text-slate-900">Select a backup</span>
              <span class="mt-1 text-sm text-slate-500">
                .zip, .db, .sqlite, or .sqlite3 up to 250 MB
              </span>
              <.live_file_input upload={@uploads.database} class="sr-only" />
            </label>

            <div
              :for={entry <- @uploads.database.entries}
              class="rounded-xl bg-slate-100 p-3 text-sm"
            >
              <div class="flex items-center justify-between gap-3">
                <span class="truncate font-medium text-slate-800">{entry.client_name}</span>
                <span class="shrink-0 text-slate-500">{entry.progress}%</span>
              </div>
              <p
                :for={error <- upload_errors(@uploads.database, entry)}
                class="mt-2 font-medium text-rose-700"
              >
                {upload_error(error)}
              </p>
            </div>

            <p :if={@validation_error} class="text-sm font-medium text-rose-700">
              {@validation_error}
            </p>

            <p class="text-sm text-slate-500" role="status">
              Your backup uploads and validates automatically after selection.
            </p>
          </.form>

          <div :if={@staged_path} id="restore-ready" class="space-y-4">
            <p class="font-semibold text-slate-900">Ready to restore</p>
            <p class="break-all text-sm text-slate-600">{@uploaded_name}</p>
            <p :if={@validation_error} class="text-sm font-medium text-rose-700">
              {@validation_error}
            </p>
            <div class="flex flex-col gap-3 sm:flex-row">
              <button
                type="button"
                id="restore-backup-button"
                phx-click="restore_database"
                phx-disable-with="Restoring..."
                class="min-h-12 rounded-xl bg-slate-950 px-5 font-semibold text-white transition hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
              >
                Restore Backup
              </button>
              <button
                type="button"
                phx-click="cancel_restore"
                class="min-h-12 rounded-xl border border-slate-300 px-5 font-semibold text-slate-700 transition hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
              >
                Choose another file
              </button>
            </div>
          </div>
        </section>

        <section
          :if={@staged_path && @show_export_warning}
          id="restore-confirmation"
          class="rounded-[2rem] border-2 border-rose-300 bg-rose-50 p-5 shadow-sm shadow-rose-100 sm:p-7"
        >
          <div class="flex items-start gap-3">
            <span class="grid size-11 shrink-0 place-items-center rounded-2xl bg-rose-100 text-rose-800">
              <.icon name="hero-exclamation-triangle" class="size-6" />
            </span>
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-rose-700">
                Backup validated
              </p>
              <h2 class="mt-1 text-xl font-semibold text-rose-950">Confirm full replacement</h2>
              <p class="mt-2 break-all text-sm font-medium text-rose-900">{@uploaded_name}</p>
            </div>
          </div>

          <p class="mt-5 text-base font-semibold leading-7 text-rose-950">
            This will replace your current reading logs, books, settings, metadata provider
            configuration, and locally stored cover art.
          </p>
          <p class="mt-2 text-sm leading-6 text-rose-900">
            This is a full database replacement. Data from the two databases will not be merged.
          </p>

          <p :if={@validation_error} class="mt-4 text-sm font-medium text-rose-800">
            {@validation_error}
          </p>

          <div class="mt-6 grid gap-3 sm:grid-cols-2">
            <button
              type="button"
              id="cancel-restore"
              phx-click="cancel_restore"
              class="min-h-14 rounded-2xl border border-slate-300 bg-white px-5 font-semibold text-slate-800 transition hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2"
            >
              Cancel
            </button>
            <button
              type="button"
              id="confirm-restore"
              phx-click="restore_database"
              data-confirm="Restore this backup and replace all current data?"
              class="min-h-14 rounded-2xl bg-rose-700 px-5 font-semibold text-white shadow-lg shadow-rose-900/15 transition hover:bg-rose-800 focus:outline-none focus:ring-2 focus:ring-rose-600 focus:ring-offset-2"
            >
              Restore Backup
            </button>
          </div>
        </section>

        <section
          :if={@restore_result}
          id="restore-complete"
          class="rounded-[2rem] border border-emerald-200 bg-emerald-50 p-5 sm:p-7"
        >
          <span class="grid size-12 place-items-center rounded-2xl bg-emerald-100 text-emerald-800">
            <.icon name="hero-check-circle" class="size-6" />
          </span>
          <h2 class="mt-4 text-2xl font-semibold text-emerald-950">Restore complete</h2>
          <p class="mt-2 text-base font-semibold leading-7 text-emerald-900">
            Restore complete. Please restart CI Book Tracker.
          </p>
          <p class="mt-3 break-all text-sm leading-6 text-emerald-800">
            Safety backup: {@restore_result.backup_path}
          </p>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp handle_upload_progress(:database, entry, socket) do
    if entry.done? do
      cleanup_staged_file(socket.assigns.staged_path)

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, DatabaseRestore.stage(path)}
        end)

      case result do
        {:ok, staged_path} ->
          {:noreply,
           socket
           |> assign(:staged_path, staged_path)
           |> assign(:uploaded_name, entry.client_name)
           |> assign(:validation_error, nil)
           |> assign(:restore_result, nil)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:staged_path, nil)
           |> assign(:uploaded_name, nil)
           |> assign(:validation_error, DatabaseRestore.error_message(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  defp cleanup_staged_file(staged), do: DatabaseRestore.cleanup_stage(staged)

  defp open_log_has_books?(session) do
    case ReadingLogSession.resolve(session) do
      {:ok, reading_log} ->
        Library.list_books!(query: [filter: [reading_log_id: reading_log.id], limit: 1]) != []

      {:error, _reason} ->
        false
    end
  end

  defp upload_error(:too_large), do: "The backup is larger than 250 MB."
  defp upload_error(:not_accepted), do: "Choose a .zip, .db, .sqlite, or .sqlite3 file."
  defp upload_error(:too_many_files), do: "Choose only one backup file."
  defp upload_error(_error), do: "The backup could not be uploaded."
end
