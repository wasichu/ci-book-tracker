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
      class="workspace-metadata"
    >
      <header class="metadata-heading">
        <h2>{metadata_heading(@book)}</h2>
        <p class="workspace-muted mt-2">{metadata_intro(@book)}</p>
      </header>

      <.form
        for={@metadata_form}
        id="metadata-search-form"
        phx-submit="search_metadata"
        class="metadata-search-form"
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
          class="workspace-button workspace-primary mt-1"
        >
          <.icon
            name={if @status == :loading, do: "hero-arrow-path", else: "hero-magnifying-glass"}
            class={if @status == :loading, do: "size-5 motion-safe:animate-spin", else: "size-5"}
          /> {if @status == :loading, do: "Search again", else: "Search"}
        </.button>
      </.form>

      <p
        :if={@message}
        id="metadata-message"
        role="status"
        class={["metadata-status", @status == :error && "is-error"]}
      >
        {@message}
      </p>

      <div :if={@results != []} id="metadata-results" class="mt-5 space-y-3">
        <article
          :for={result <- @results}
          id={"metadata-result-#{result.id}"}
          class="metadata-result"
        >
          <img
            :if={result.cover_url}
            src={result.cover_url}
            alt={"Cover of #{result.title}"}
            class="h-24 w-16 shrink-0 rounded-lg bg-slate-100 object-cover"
          />
          <div class="metadata-result-details min-w-0">
            <div class="flex flex-wrap items-start justify-between gap-2">
              <h3 class="font-semibold leading-6 text-slate-950">{result.title}</h3>
              <span class="metadata-provider-label">
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
                class="workspace-button workspace-primary"
              >
                <.icon name="hero-arrow-down-tray" class="size-4" /> Use this book
              </button>
              <button
                :if={result.cover_url}
                type="button"
                phx-click="select_cover"
                phx-value-id={result.id}
                class="workspace-button"
              >
                <.icon name="hero-photo" class="size-4" /> Use cover only
              </button>
              <button
                :if={@selected_cover_result_id == result.id}
                id={"save-selected-cover-#{result.id}"}
                type="submit"
                form={@book_form_id}
                phx-disable-with="Saving..."
                class="workspace-button workspace-primary"
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
        class="metadata-review"
      >
        <p class="text-xs font-semibold uppercase tracking-[0.16em] text-amber-800">
          Use this book
        </p>
        <h3 class="mt-2 text-lg font-semibold text-slate-950">{@pending_metadata.title}</h3>
        <p :if={@pending_metadata.author} class="mt-1 text-sm text-slate-600">
          {@pending_metadata.author}
        </p>

        <dl class="mt-4 text-sm">
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
            class="workspace-button workspace-primary"
          >
            <.icon name="hero-check" class="size-4" /> Apply metadata
          </button>
          <button
            id="cancel-metadata"
            type="button"
            phx-click="cancel_metadata"
            class="workspace-button"
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

  attr :active_tab, :string, default: "book"

  def book_fields(assigns) do
    ~H"""
    <input type="hidden" name={@form[:cover_url].name} value={@form[:cover_url].value} />
    <input type="hidden" name={@form[:cover_path].name} value={@form[:cover_path].value} />
    <input type="hidden" name={@form[:cover_provider].name} value={@form[:cover_provider].value} />
    <input type="hidden" name={@form[:cover_id].name} value={@form[:cover_id].value} />

    <div id="editor-panel-book" hidden={@active_tab != "book"} class="workspace-editor-fields">
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
        class="workspace-calculated-words"
      >
        <input
          type="hidden"
          name={@form[:estimated_words].name}
          value={@form[:estimated_words].value}
        />
        <input type="hidden" name={@form[:estimated_words_mode].name} value="calculated" />
        <span>Estimated Total Words</span><strong>{BookFormat.number(@form[:estimated_words].value)}</strong>
        <span class="text-xs">Using 250 words per page</span>
        <button
          id="enter-word-estimate"
          type="button"
          phx-click="enter_word_estimate"
          class="workspace-text-button"
        >Enter your own estimate</button>
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
        <p :if={is_nil(@book)} class="workspace-muted text-xs -mt-2">
          Enter a total, or open the Word estimate tab.
        </p>
      </div>
      <.input
        field={@form[:difficulty_label]}
        label="Difficulty"
        placeholder="A1, B2, intermediate…"
        autocomplete="off"
      />
      <.input field={@form[:status]} type="select" label="Reading status" options={@status_options} />
    </div>

    <div id="editor-panel-estimate" hidden={@active_tab != "estimate"}>
      <WordEstimatorComponents.panel
        form={@estimator_form}
        result={@estimator_result}
        apply_event="apply_word_estimate"
      />
    </div>

    <fieldset id="editor-panel-cover" hidden={@active_tab != "cover"} class="workspace-editor-cover">
      <legend class="sr-only">Cover art</legend>
      <div>
        <.input
          field={@form[:cover_image_url]}
          type="url"
          label="Cover image URL"
          placeholder="https://…"
          autocomplete="off"
        />
        <label for={@uploads.cover_art.ref} class="block text-sm font-medium mb-2">Upload cover image</label>
        <.live_file_input upload={@uploads.cover_art} class="workspace-file-input" />
        <p class="workspace-muted text-xs mt-2 leading-5">
          JPG, PNG, WebP, or GIF up to 8 MB. Uploaded files take precedence over URLs.
        </p>
        <p
          :for={entry <- @uploads.cover_art.entries}
          id={"cover-upload-#{entry.ref}"}
          class="text-xs mt-3"
        >
          {entry.client_name} · {entry.progress}%
        </p>
        <p :for={error <- upload_errors(@uploads.cover_art)} class="mt-2 text-xs text-red-700">
          {cover_upload_error(error)}
        </p>
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
    </fieldset>

    <fieldset id="editor-panel-history" hidden={@active_tab != "history"}>
      <legend class="sr-only">Reading dates</legend>
      <p class="workspace-muted text-sm mb-5">
        Optional. Missing dates are filled automatically for in-progress and finished books.
      </p>
      <div class="workspace-editor-fields">
        <.input field={@form[:started_on]} type="date" label="Started on" />
        <.input field={@form[:finished_on]} type="date" label="Finished on" />
      </div>
    </fieldset>

    <div id="editor-panel-notes" hidden={@active_tab != "notes"}>
      <.input
        field={@form[:notes]}
        type="textarea"
        label="Notes"
        placeholder="Why this book, reading plan, edition details…"
        rows="8"
      />
    </div>

    <footer class="workspace-editor-footer">
      <span class="workspace-muted text-xs">{if @book,
        do: "Changes are saved when you choose Save changes.",
        else: "Only a title is required."}</span>
      <.button
        id="save-book"
        type="submit"
        phx-disable-with="Saving…"
        class="workspace-button workspace-primary"
      ><.icon name="hero-check" class="size-4" /> {@save_label}</.button>
    </footer>
    """
  end

  defp metadata_heading(nil), do: "Find metadata"
  defp metadata_heading(_book), do: "Refresh metadata"

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
