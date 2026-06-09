defmodule CiBookTrackerWeb.BookLive.Import do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCsvImport
  alias CiBookTrackerWeb.BookFormat

  @impl true
  def mount(_params, session, socket) do
    case active_reading_log(session) do
      nil ->
        {:ok,
         socket
         |> put_flash(:info, "Choose a reading log to continue.")
         |> push_navigate(to: ~p"/")}

      reading_log ->
        {:ok,
         socket
         |> assign(:page_title, "Import books")
         |> assign(:reading_log, reading_log)
         |> assign(:preview, nil)
         |> assign(:file_errors, [])
         |> assign(:import_summary, nil)
         |> allow_upload(:csv, accept: [".csv"], max_entries: 1, max_file_size: 2_000_000)}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply,
     socket
     |> assign(:preview, nil)
     |> assign(:file_errors, [])
     |> assign(:import_summary, nil)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv, ref)}
  end

  def handle_event("preview", _params, socket) do
    results =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        {:ok, path |> File.read!() |> BookCsvImport.preview()}
      end)

    case results do
      [{:ok, preview}] ->
        {:noreply,
         socket
         |> assign(:preview, preview)
         |> assign(:file_errors, [])
         |> assign(:import_summary, nil)}

      [{:error, errors}] ->
        {:noreply,
         socket
         |> assign(:preview, nil)
         |> assign(:file_errors, errors)
         |> assign(:import_summary, nil)}

      [] ->
        {:noreply, assign(socket, :file_errors, ["Choose a CSV file to preview."])}
    end
  end

  def handle_event("confirm_import", _params, %{assigns: %{preview: preview}} = socket)
      when not is_nil(preview) do
    summary = BookCsvImport.import(preview, socket.assigns.reading_log.id)

    {:noreply,
     socket
     |> assign(:preview, nil)
     |> assign(:import_summary, summary)
     |> put_flash(:info, import_message(summary))}
  end

  def handle_event("confirm_import", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="book-import-page" class="space-y-7">
        <header>
          <.link
            navigate={~p"/dashboard"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to dashboard
          </.link>
          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            {@reading_log.name}
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Import books
          </h1>
          <p class="mt-3 max-w-2xl text-base leading-7 text-slate-600">
            Upload a CSV, review every row, then import the valid books into this reading log.
          </p>
        </header>

        <section
          id="csv-upload"
          class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-7"
        >
          <div class="flex items-start gap-3">
            <span class="grid size-11 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
              <.icon name="hero-document-arrow-up" class="size-5" />
            </span>
            <div>
              <h2 class="text-lg font-semibold text-slate-950">Choose a CSV file</h2>
              <p class="mt-1 text-sm leading-6 text-slate-600">
                The title column is required. Files can be up to 2 MB.
              </p>
            </div>
          </div>

          <.form
            for={to_form(%{}, as: :import)}
            id="csv-upload-form"
            phx-change="validate_upload"
            phx-submit="preview"
            class="mt-6 space-y-4"
          >
            <label
              for={@uploads.csv.ref}
              class="flex min-h-36 cursor-pointer flex-col items-center justify-center rounded-2xl border-2 border-dashed border-slate-300 bg-slate-50 px-5 text-center transition hover:border-amber-500 hover:bg-amber-50/60"
            >
              <.icon name="hero-arrow-up-tray" class="size-7 text-slate-500" />
              <span class="mt-3 font-semibold text-slate-900">Select a CSV file</span>
              <span class="mt-1 text-sm text-slate-500">or drop it here</span>
              <.live_file_input upload={@uploads.csv} class="sr-only" />
            </label>

            <div :for={entry <- @uploads.csv.entries} class="rounded-xl bg-slate-100 p-3 text-sm">
              <div class="flex items-center justify-between gap-3">
                <span class="truncate font-medium text-slate-800">{entry.client_name}</span>
                <div class="flex shrink-0 items-center gap-2">
                  <span :if={entry.progress > 0} class="text-slate-500">
                    {entry.progress}%
                  </span>
                  <button
                    type="button"
                    id={"cancel-upload-#{entry.ref}"}
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    aria-label={"Remove #{entry.client_name}"}
                    title="Remove file"
                    class="inline-flex size-8 items-center justify-center rounded-lg text-slate-500 transition hover:bg-white hover:text-rose-700 focus:outline-none focus:ring-2 focus:ring-rose-500 focus:ring-offset-2"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>
              </div>
              <p
                :for={error <- upload_errors(@uploads.csv, entry)}
                class="mt-2 font-medium text-rose-700"
              >
                {upload_error(error)}
              </p>
            </div>

            <p :for={error <- @file_errors} class="text-sm font-medium text-rose-700">
              {error}
            </p>

            <.button
              type="submit"
              id="preview-import"
              phx-disable-with="Reading CSV..."
              class="flex min-h-12 w-full items-center justify-center rounded-xl bg-slate-950 px-5 font-semibold text-white transition hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 sm:w-auto"
            >
              Import
            </.button>
          </.form>
        </section>

        <section
          :if={@preview}
          id="import-preview"
          class="space-y-5 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-7"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
              Review before importing
            </p>
            <h2 class="mt-2 text-2xl font-semibold tracking-tight text-slate-950">
              {@preview.valid_count} valid, {@preview.invalid_count} invalid
            </h2>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              Invalid rows will not be imported. Correct them in the CSV and upload it again.
            </p>
          </div>

          <div id="import-rows" class="space-y-3">
            <article
              :for={row <- @preview.rows}
              id={"import-row-#{row.number}"}
              class={[
                "rounded-2xl border p-4",
                row.errors == [] && "border-emerald-200 bg-emerald-50/60",
                row.errors != [] && "border-rose-200 bg-rose-50/60"
              ]}
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="text-xs font-semibold uppercase tracking-[0.15em] text-slate-500">
                    Row {row.number}
                  </p>
                  <h3 class="mt-1 truncate font-semibold text-slate-950">
                    {row.attributes.title || "Untitled row"}
                  </h3>
                  <p :if={row.attributes.author} class="mt-1 truncate text-sm text-slate-600">
                    {row.attributes.author}
                  </p>
                </div>
                <span class={[
                  "shrink-0 rounded-full px-3 py-1 text-xs font-semibold",
                  row.errors == [] && "bg-emerald-100 text-emerald-800",
                  row.errors != [] && "bg-rose-100 text-rose-800"
                ]}>
                  {if row.errors == [], do: "Ready", else: "Invalid"}
                </span>
              </div>

              <dl :if={row.errors == []} class="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm">
                <div>
                  <dt class="inline text-slate-500">Status:</dt>
                  <dd class="inline font-medium text-slate-800">
                    {BookFormat.status_label(row.attributes.status)}
                  </dd>
                </div>
                <div :if={row.attributes.page_count}>
                  <dt class="inline text-slate-500">Pages:</dt>
                  <dd class="inline font-medium text-slate-800">{row.attributes.page_count}</dd>
                </div>
                <div :if={row.attributes.estimated_words}>
                  <dt class="inline text-slate-500">Words:</dt>
                  <dd class="inline font-medium text-slate-800">
                    {BookFormat.number(row.attributes.estimated_words)}
                  </dd>
                </div>
              </dl>

              <ul :if={row.errors != []} class="mt-3 space-y-1 text-sm font-medium text-rose-800">
                <li :for={error <- row.errors} class="flex gap-2">
                  <.icon name="hero-exclamation-circle" class="mt-0.5 size-4 shrink-0" />
                  {error}
                </li>
              </ul>
            </article>
          </div>

          <.button
            :if={@preview.valid_count > 0}
            type="button"
            id="confirm-import"
            phx-click="confirm_import"
            phx-disable-with="Importing books..."
            class="flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-amber-600 px-5 font-semibold text-white transition hover:-translate-y-0.5 hover:bg-amber-700 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
          >
            <.icon name="hero-check" class="size-5" />
            Import {@preview.valid_count} {if @preview.valid_count == 1, do: "book", else: "books"}
          </.button>
        </section>

        <section
          :if={@import_summary}
          id="import-summary"
          class="rounded-[2rem] border border-emerald-200 bg-emerald-50 p-5 sm:p-7"
        >
          <h2 class="text-xl font-semibold text-emerald-950">Import complete</h2>
          <p class="mt-2 text-sm leading-6 text-emerald-900">
            Imported {@import_summary.imported} {book_label(@import_summary.imported)}. {length(
              @import_summary.failed
            )} failed while saving.
          </p>
          <ul :if={@import_summary.failed != []} class="mt-4 space-y-2 text-sm text-rose-800">
            <li :for={failure <- @import_summary.failed}>
              Row {failure.row}, {failure.title}: {failure.reason}
            </li>
          </ul>
          <.link
            navigate={~p"/dashboard"}
            class="mt-5 inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-emerald-900 px-5 font-semibold text-white transition hover:bg-slate-950 focus:outline-none focus:ring-2 focus:ring-emerald-700 focus:ring-offset-2"
          >
            View reading shelf <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </section>

        <section id="csv-header-help" class="rounded-2xl bg-slate-100 p-5">
          <h2 class="font-semibold text-slate-950">Title Column</h2>
          <p class="mt-2 text-sm leading-6 text-slate-600">
            The first row in your CSV file of books must be this header containing the supported columns for bulk book imports.
          </p>
          <div class="mt-3 rounded-xl border border-slate-200 bg-white p-3">
            <code
              id="csv-header-value"
              class="block overflow-x-auto whitespace-nowrap font-mono text-xs leading-6 text-slate-700"
            >
              title,author,status,page_count,estimated_words,difficulty_label,started_on,finished_on,notes
            </code>
            <button
              id="copy-csv-header"
              type="button"
              phx-hook="ClipboardCopy"
              data-copy-text="title,author,status,page_count,estimated_words,difficulty_label,started_on,finished_on,notes"
              class="mt-3 inline-flex min-h-11 items-center gap-2 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white transition hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
            >
              <.icon name="hero-clipboard-document" class="size-4" />
              <span data-copy-label>Copy header</span>
            </button>
          </div>
          <div class="mt-5 space-y-5 text-sm leading-6 text-slate-600">
            <div>
              <h3 class="font-semibold text-slate-950">Required fields</h3>
              <p class="mt-1 font-mono text-xs">title</p>
            </div>
            <div>
              <h3 class="font-semibold text-slate-950">Allowed statuses</h3>
              <p class="mt-1 font-mono text-xs">
                want_to_read, in_progress, finished, abandoned
              </p>
              <p class="mt-1">
                Defaults to <span class="font-mono text-xs">want_to_read</span> when blank.
              </p>
            </div>
            <div>
              <h3 class="font-semibold text-slate-950">Date format</h3>
              <p class="mt-1 font-mono text-xs">YYYY-MM-DD</p>
            </div>
            <div>
              <h3 class="font-semibold text-slate-950">Optional fields</h3>
              <p class="mt-1">All other fields are optional.</p>
            </div>
          </div>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp active_reading_log(session) do
    id = session["active_reading_log_id"] || session["auto_open_reading_log_id"]

    case id && Library.get_reading_log(id) do
      {:ok, reading_log} -> reading_log
      _missing -> nil
    end
  end

  defp import_message(%{imported: imported, failed: []}),
    do: "Imported #{imported} #{if imported == 1, do: "book", else: "books"}."

  defp import_message(%{imported: imported, failed: failed}),
    do: "Imported #{imported} books; #{length(failed)} could not be saved."

  defp book_label(1), do: "book"
  defp book_label(_count), do: "books"

  defp upload_error(:too_large), do: "The file is larger than 2 MB."
  defp upload_error(:not_accepted), do: "Choose a .csv file."
  defp upload_error(:too_many_files), do: "Choose only one CSV file."
  defp upload_error(_error), do: "The file could not be uploaded."
end
