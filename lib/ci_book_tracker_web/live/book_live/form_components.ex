defmodule CiBookTrackerWeb.BookLive.FormComponents do
  use CiBookTrackerWeb, :html

  alias CiBookTrackerWeb.BookFormat
  alias CiBookTrackerWeb.BookLive.FormParams
  alias CiBookTrackerWeb.WordEstimatorComponents

  attr :book, :any, default: nil
  attr :query, :string, required: true
  attr :provider, :string, required: true
  attr :provider_options, :list, required: true
  attr :results, :list, required: true
  attr :status, :atom, required: true
  attr :message, :string, default: nil
  attr :pending_metadata, :any, default: nil
  attr :selected_cover_result_id, :string, default: nil
  attr :book_form_id, :string, required: true
  attr :save_label, :string, required: true

  def metadata_search(assigns) do
    assigns =
      assign(
        assigns,
        :metadata_form,
        to_form(%{"query" => assigns.query, "provider" => assigns.provider}, as: :metadata)
      )

    ~H"""
    <section
      id="metadata-search"
      class="rounded-[2rem] border border-amber-200 bg-gradient-to-br from-amber-50 to-white p-5 shadow-sm shadow-amber-100/70 sm:p-7"
    >
      <div class="flex items-start gap-3">
        <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-800">
          <.icon name="hero-magnifying-glass" class="size-5" />
        </span>
        <div>
          <h2 class="text-lg font-semibold text-slate-950">{metadata_heading(@book)}</h2>
          <p class="mt-1 text-sm leading-6 text-slate-600">{metadata_intro(@book)}</p>
        </div>
      </div>

      <.form
        for={@metadata_form}
        id="metadata-search-form"
        phx-submit="search_metadata"
        class="mt-5"
      >
        <.input
          field={@metadata_form[:provider]}
          type="select"
          label="Metadata source"
          options={@provider_options}
        />
        <.input
          field={@metadata_form[:query]}
          label="Title, author, ISBN, or keywords"
          placeholder="Cien anos de soledad or 9780307474728"
          autocomplete="off"
        />
        <.button
          id="search-metadata-button"
          type="submit"
          phx-disable-with="Searching..."
          class="mt-1 flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 font-semibold text-white transition hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 sm:w-auto"
        >
          <.icon name="hero-magnifying-glass" class="size-5" /> Search
        </.button>
      </.form>

      <p
        :if={@message}
        id="metadata-message"
        class={[
          "mt-4 rounded-xl px-4 py-3 text-sm leading-6",
          @status == :error && "bg-red-50 text-red-800",
          @status != :error && "bg-white text-slate-700 ring-1 ring-slate-200"
        ]}
      >
        {@message}
      </p>

      <div :if={@results != []} id="metadata-results" class="mt-5 space-y-3">
        <article
          :for={result <- @results}
          id={"metadata-result-#{result.id}"}
          class="flex gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
        >
          <img
            :if={result.cover_url}
            src={result.cover_url}
            alt={"Cover of #{result.title}"}
            class="h-24 w-16 shrink-0 rounded-lg bg-slate-100 object-cover"
          />
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-start justify-between gap-2">
              <h3 class="font-semibold leading-6 text-slate-950">{result.title}</h3>
              <span class="rounded-full bg-slate-100 px-2.5 py-1 text-[0.7rem] font-semibold text-slate-600">
                {metadata_provider_label(result.provider)}
              </span>
            </div>
            <p :if={result.author} class="mt-0.5 text-sm text-slate-600">{result.author}</p>
            <p class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-slate-500">
              <span :if={result.publish_year}>{result.publish_year}</span>
              <span :if={result.language_code}>{String.upcase(result.language_code)}</span>
              <span :if={result.page_count}>{result.page_count} pages</span>
            </p>
            <div class="mt-3 flex flex-col gap-2 sm:flex-row">
              <button
                type="button"
                phx-click="select_metadata"
                phx-value-id={result.id}
                class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-amber-100 px-4 text-sm font-semibold text-amber-950 transition hover:bg-amber-200 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 sm:w-auto"
              >
                <.icon name="hero-arrow-down-tray" class="size-4" /> Use this book
              </button>
              <button
                :if={result.cover_url}
                type="button"
                phx-click="select_cover"
                phx-value-id={result.id}
                class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 text-sm font-semibold text-slate-700 transition hover:border-amber-400 hover:bg-amber-50 hover:text-amber-900 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 sm:w-auto"
              >
                <.icon name="hero-photo" class="size-4" /> Use cover only
              </button>
              <button
                :if={@selected_cover_result_id == result.id}
                id={"save-selected-cover-#{result.id}"}
                type="submit"
                form={@book_form_id}
                phx-disable-with="Saving..."
                class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-amber-700 px-4 text-sm font-semibold text-white shadow-sm shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0 disabled:translate-y-0 sm:w-auto"
              >
                <.icon name="hero-book-open" class="size-4" /> {@save_label}
              </button>
            </div>
          </div>
        </article>
      </div>

      <section
        :if={@pending_metadata}
        id="metadata-review"
        class="mt-5 rounded-2xl border border-amber-300 bg-amber-50 p-4 sm:p-5"
      >
        <p class="text-xs font-semibold uppercase tracking-[0.16em] text-amber-800">
          Use this book
        </p>
        <h3 class="mt-2 text-lg font-semibold text-slate-950">{@pending_metadata.title}</h3>
        <p :if={@pending_metadata.author} class="mt-1 text-sm text-slate-600">
          {@pending_metadata.author}
        </p>

        <dl class="mt-4 divide-y divide-amber-200 text-sm">
          <div class="flex items-center justify-between gap-4 py-3">
            <dt class="text-slate-600">Cover</dt>
            <dd class="font-semibold text-slate-900">
              {if @pending_metadata.cover_url, do: "Available", else: "Not available"}
            </dd>
          </div>
          <div class="flex items-center justify-between gap-4 py-3">
            <dt class="text-slate-600">Page count</dt>
            <dd class="font-semibold text-slate-900">
              {@pending_metadata.page_count || "Not available"}
            </dd>
          </div>
          <div
            :if={@pending_metadata.page_count}
            class="flex items-center justify-between gap-4 py-3"
          >
            <dt class="text-slate-600">Estimated total words</dt>
            <dd class="font-semibold text-slate-900">
              {BookFormat.number(@pending_metadata.page_count * 250)}
            </dd>
          </div>
        </dl>

        <p class="mt-4 text-xs leading-5 text-slate-600">
          Title, author, notes, reading status, and reading dates will not be changed.
        </p>
        <div class="mt-4 grid gap-2 sm:grid-cols-2">
          <button
            id="apply-metadata"
            type="button"
            phx-click="apply_metadata"
            class="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-amber-700 px-4 text-sm font-semibold text-white transition hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-check" class="size-4" /> Apply Metadata
          </button>
          <button
            id="cancel-metadata"
            type="button"
            phx-click="cancel_metadata"
            class="inline-flex min-h-12 items-center justify-center rounded-xl border border-amber-300 bg-white px-4 text-sm font-semibold text-slate-700 transition hover:bg-amber-100 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            Cancel
          </button>
        </div>
      </section>
    </section>
    """
  end

  attr :form, :map, required: true
  attr :book, :any, default: nil
  attr :estimator_form, :map, required: true
  attr :estimator_result, :map, required: true
  attr :uploads, :map, required: true
  attr :status_options, :list, required: true
  attr :save_label, :string, required: true

  def book_fields(assigns) do
    ~H"""
    <input type="hidden" name={@form[:cover_url].name} value={@form[:cover_url].value} />
    <input type="hidden" name={@form[:cover_path].name} value={@form[:cover_path].value} />
    <input type="hidden" name={@form[:cover_provider].name} value={@form[:cover_provider].value} />
    <input type="hidden" name={@form[:cover_id].name} value={@form[:cover_id].value} />

    <.input
      field={@form[:title]}
      label="Title"
      placeholder="The Little Prince"
      required
      autocomplete="off"
    />
    <.input
      field={@form[:author]}
      label="Author"
      placeholder="Antoine de Saint-Exupery"
      autocomplete="off"
    />

    <div class="space-y-4">
      <.input
        field={@form[:page_count]}
        type="number"
        label="Page count"
        placeholder="96"
        min="1"
        inputmode="numeric"
      />

      <div
        :if={FormParams.calculated_estimate?(@form)}
        id="calculated-estimated-words"
        class="rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-5"
      >
        <input
          type="hidden"
          name={@form[:estimated_words].name}
          value={@form[:estimated_words].value}
        />
        <input type="hidden" name={@form[:estimated_words_mode].name} value="calculated" />
        <p class="text-sm font-medium text-slate-600">Estimated Total Words</p>
        <p class="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
          {BookFormat.number(@form[:estimated_words].value)}
        </p>
        <p class="mt-1 flex items-center gap-1.5 text-xs leading-5 text-slate-500">
          <.icon name="hero-calculator" class="size-4" /> Using 250 words per page
        </p>
        <button
          id="enter-word-estimate"
          type="button"
          phx-click="enter_word_estimate"
          class="mt-3 inline-flex items-center gap-1.5 rounded-lg text-sm font-semibold text-teal-700 transition-colors hover:text-teal-900 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-teal-600"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Enter your own estimate
        </button>
      </div>

      <div :if={!FormParams.calculated_estimate?(@form)}>
        <input
          type="hidden"
          name={@form[:estimated_words_mode].name}
          value={@form[:estimated_words_mode].value}
        />
        <.input
          field={@form[:estimated_words]}
          type="number"
          label="Estimated Total Words"
          placeholder="24000"
          min="1"
          inputmode="numeric"
        />
        <p :if={is_nil(@book)} class="-mt-2 text-xs leading-5 text-slate-500">
          Enter the book's total word count, such as an estimate you found online, or use the helper below.
        </p>
      </div>
    </div>

    <WordEstimatorComponents.panel
      form={@estimator_form}
      result={@estimator_result}
      apply_event="apply_word_estimate"
    />

    <fieldset class="rounded-2xl border border-slate-200 bg-slate-50/70 p-4 sm:p-5">
      <legend class="px-1 text-sm font-semibold text-slate-700">Cover art</legend>
      <div class="mt-4 grid gap-5 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-start">
        <div class="space-y-4">
          <.input
            field={@form[:cover_image_url]}
            type="url"
            label="Cover image URL"
            placeholder="https://m.media-amazon.com/images/I/71WLpK0hFYL._SL1499_.jpg"
            autocomplete="off"
          />
          <div>
            <label
              for={@uploads.cover_art.ref}
              class="block text-sm font-semibold leading-6 text-slate-900"
            >
              Upload cover image
            </label>
            <.live_file_input
              upload={@uploads.cover_art}
              class="mt-2 block w-full rounded-xl border border-slate-300 bg-white px-3 py-3 text-sm text-slate-700 file:mr-4 file:rounded-lg file:border-0 file:bg-slate-900 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white hover:file:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
            />
            <p class="mt-2 text-xs leading-5 text-slate-500">
              JPG, PNG, WebP, or GIF up to 8 MB. Uploaded files take precedence over URLs.
            </p>
            <p
              :for={entry <- @uploads.cover_art.entries}
              id={"cover-upload-#{entry.ref}"}
              class="mt-2 text-xs font-medium text-slate-600"
            >
              {entry.client_name} · {entry.progress}%
            </p>
            <p
              :for={error <- upload_errors(@uploads.cover_art)}
              class="mt-2 text-xs font-semibold text-red-700"
            >
              {cover_upload_error(error)}
            </p>
          </div>
        </div>

        <.book_cover
          id="cover-preview"
          title={FormParams.cover_preview_title(@form)}
          cover_path={@form[:cover_path].value}
          cover_url={FormParams.cover_preview_url(@form)}
          cover_provider={@form[:cover_provider].value}
          cover_id={FormParams.cover_preview_id(@form[:cover_id].value)}
          size={:detail}
        />
      </div>
    </fieldset>

    <.input
      field={@form[:difficulty_label]}
      label="Difficulty"
      placeholder="Beginner, intermediate, advanced, A1, B2, ..."
      autocomplete="off"
    />

    <div class="rounded-2xl border border-amber-200 bg-amber-50/60 p-4 sm:p-5">
      <.input
        field={@form[:status]}
        type="select"
        label="Reading status"
        options={@status_options}
      />
      <p class="-mt-2 text-xs leading-5 text-amber-900/70">
        Adding a book you've already started or finished? Set its status here.
      </p>
    </div>

    <fieldset class="rounded-2xl border border-slate-200 bg-slate-50/70 p-4 sm:p-5">
      <legend class="px-1 text-sm font-semibold text-slate-700">Reading dates</legend>
      <p class="mt-1 text-xs leading-5 text-slate-500">
        Optional. Missing dates are filled automatically for in-progress and finished books.
      </p>
      <div class="mt-4 grid gap-5 sm:grid-cols-2">
        <.input field={@form[:started_on]} type="date" label="Started on" />
        <.input field={@form[:finished_on]} type="date" label="Finished on" />
      </div>
    </fieldset>

    <.input
      field={@form[:notes]}
      type="textarea"
      label="Notes"
      placeholder="Why this book, reading plan, edition details..."
      rows="5"
    />

    <div class="border-t border-slate-100 pt-6">
      <.button
        id="save-book"
        type="submit"
        variant="primary"
        phx-disable-with="Saving..."
        class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-amber-700 px-6 text-base font-semibold text-white shadow-lg shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0 disabled:translate-y-0"
      >
        <.icon name="hero-book-open" class="size-5" /> {@save_label}
      </.button>
    </div>
    """
  end

  defp metadata_heading(nil), do: "Find Metadata"
  defp metadata_heading(_book), do: "Refresh Metadata"

  defp metadata_intro(nil), do: "Optional. Find a book, then review the details before saving."

  defp metadata_intro(_book),
    do:
      "Search for a cover and missing book details without replacing your saved title or author."

  defp metadata_provider_label(:google_books), do: "Google Books"
  defp metadata_provider_label(:hardcover), do: "Hardcover"
  defp metadata_provider_label(_provider), do: "Open Library"

  defp cover_upload_error(:too_large), do: "Choose an image smaller than 8 MB."
  defp cover_upload_error(:not_accepted), do: "Choose a JPG, PNG, WebP, or GIF image."
  defp cover_upload_error(_error), do: "The cover image could not be uploaded."
end
