defmodule CiBookTrackerWeb.BookLive.Form do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookMetadata
  alias CiBookTracker.Library.WordEstimator
  alias CiBookTracker.Settings.MetadataProviders
  alias CiBookTrackerWeb.BookFormat

  @empty_params %{
    "title" => "",
    "author" => "",
    "page_count" => "",
    "estimated_words" => "",
    "estimated_words_mode" => "manual",
    "cover_url" => "",
    "cover_provider" => "",
    "cover_id" => "",
    "difficulty_label" => "",
    "status" => "want_to_read",
    "started_on" => "",
    "finished_on" => "",
    "notes" => ""
  }

  @status_options [
    {"Want to read", "want_to_read"},
    {"In progress", "in_progress"},
    {"Finished", "finished"},
    {"Abandoned", "abandoned"}
  ]

  @estimator_params %{
    "sample_text" => "",
    "sample_units" => "",
    "total_units" => "",
    "unit_type" => "pages"
  }

  @unit_options [
    {"Pages", "pages"},
    {"Kindle locations", "kindle_locations"},
    {"Screens", "screens"},
    {"Chapters", "chapters"},
    {"Percent", "percent"}
  ]

  @impl true
  def mount(params, session, socket) do
    reading_log = active_reading_log(session)

    with %{} <- reading_log,
         {:ok, book} <- load_book(socket.assigns.live_action, params, reading_log) do
      metadata_refresh? = metadata_refresh?(book, params)

      {:ok,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:reading_log, reading_log)
       |> assign(:book, book)
       |> assign(:status_options, @status_options)
       |> assign(:unit_options, @unit_options)
       |> assign(:estimator_form, to_form(@estimator_params, as: :estimator))
       |> assign(:estimator_result, %{sample_words: 0, estimated_words: nil, message: nil})
       |> assign(:metadata_provider_options, metadata_provider_options())
       |> assign(:metadata_provider, "open_library")
       |> assign(:metadata_refresh?, metadata_refresh?)
       |> assign(:metadata_query, initial_metadata_query(book, metadata_refresh?))
       |> assign(:metadata_results, [])
       |> assign(:metadata_status, :idle)
       |> assign(:metadata_message, nil)
       |> assign(:pending_metadata, nil)
       |> assign(:form, to_form(form_params(book), as: :book))}
    else
      _missing ->
        {:ok,
         socket
         |> put_flash(:error, missing_message(socket.assigns.live_action))
         |> push_navigate(to: missing_path(reading_log))}
    end
  end

  @impl true
  def handle_event("validate", %{"book" => params, "estimator" => estimator_params}, socket) do
    params = sync_estimated_words(params, socket.assigns.book)

    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :book))
     |> update_estimator(estimator_params)}
  end

  def handle_event("validate", %{"book" => params}, socket) do
    params = sync_estimated_words(params, socket.assigns.book)
    {:noreply, assign(socket, :form, to_form(params, as: :book))}
  end

  def handle_event("apply_word_estimate", _params, socket) do
    case socket.assigns.estimator_result.estimated_words do
      estimate when is_integer(estimate) and estimate > 0 ->
        params =
          socket.assigns.form.params
          |> Map.put("estimated_words", Integer.to_string(estimate))
          |> Map.put("estimated_words_mode", "sample")

        {:noreply, assign(socket, :form, to_form(params, as: :book))}

      _invalid ->
        {:noreply, socket}
    end
  end

  def handle_event("save", %{"book" => params}, socket) do
    params =
      params
      |> sync_estimated_words(socket.assigns.book)
      |> normalize_params()

    if blank?(params["title"]) do
      form =
        to_form(params,
          as: :book,
          action: :validate,
          errors: [title: {"can't be blank", []}]
        )

      {:noreply, assign(socket, :form, form)}
    else
      save_book(socket, params)
    end
  end

  def handle_event("search_metadata", %{"metadata" => metadata_params}, socket) do
    query = metadata_params["query"] || ""
    provider = metadata_provider(metadata_params["provider"])
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:metadata_provider, Atom.to_string(provider))
       |> assign(:metadata_query, query)
       |> assign(:metadata_results, [])
       |> assign(:metadata_status, :error)
       |> assign(:metadata_message, "Enter a title, author, ISBN, or keyword to search.")}
    else
      case BookMetadata.lookup_book(query,
             language_code: socket.assigns.reading_log.language_code,
             provider: provider
           ) do
        {:ok, search} ->
          message =
            search.message ||
              if(search.results == [], do: "No matching books found. Try a broader search.")

          {:noreply,
           socket
           |> assign(:metadata_provider, Atom.to_string(provider))
           |> assign(:metadata_query, query)
           |> assign(:metadata_results, search.results)
           |> assign(:metadata_status, search.status)
           |> assign(:metadata_message, message)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:metadata_provider, Atom.to_string(provider))
           |> assign(:metadata_query, query)
           |> assign(:metadata_results, [])
           |> assign(:metadata_status, :error)
           |> assign(:metadata_message, metadata_error_message(reason))}
      end
    end
  end

  def handle_event("select_metadata", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.metadata_results, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      result when not is_nil(socket.assigns.book) ->
        {:noreply,
         socket
         |> assign(:pending_metadata, result)
         |> assign(:metadata_status, :review)
         |> assign(
           :metadata_message,
           "Review the metadata below. Nothing changes until you apply it."
         )}

      result ->
        params =
          socket.assigns.form.params
          |> Map.put("title", result.title)
          |> put_if_present("author", result.author)
          |> put_if_present("page_count", result.page_count)
          |> put_metadata_estimate(result.page_count)
          |> put_if_present("cover_url", result.cover_url)
          |> put_if_present("cover_provider", result.cover_provider)
          |> put_if_present("cover_id", result.cover_id)

        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :book))
         |> assign(:metadata_status, :selected)
         |> assign(:metadata_message, "Metadata added to the form. Review it before saving.")}
    end
  end

  def handle_event("apply_metadata", _params, socket) do
    case socket.assigns.pending_metadata do
      nil ->
        {:noreply, socket}

      result ->
        params =
          socket.assigns.form.params
          |> put_if_present("page_count", result.page_count)
          |> put_metadata_estimate(result.page_count)
          |> put_if_present("cover_url", result.cover_url)
          |> put_if_present("cover_provider", result.cover_provider)
          |> put_if_present("cover_id", result.cover_id)

        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :book))
         |> assign(:pending_metadata, nil)
         |> assign(:metadata_status, :selected)
         |> assign(
           :metadata_message,
           "Metadata applied to the form. Review the changes, then save the book."
         )}
    end
  end

  def handle_event("cancel_metadata", _params, socket) do
    {:noreply,
     socket
     |> assign(:pending_metadata, nil)
     |> assign(:metadata_status, :idle)
     |> assign(:metadata_message, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="add-book-page" class="space-y-7">
        <header>
          <.link
            navigate={back_path(@book)}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to dashboard
          </.link>

          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            {@reading_log.name}
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            {form_heading(@book)}
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            {form_intro(@book)}
          </p>
        </header>

        <section
          :if={is_nil(@book) || @metadata_refresh?}
          id="metadata-search"
          class="rounded-[2rem] border border-amber-200 bg-gradient-to-br from-amber-50 to-white p-5 shadow-sm shadow-amber-100/70 sm:p-7"
        >
          <div class="flex items-start gap-3">
            <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-800">
              <.icon name="hero-magnifying-glass" class="size-5" />
            </span>
            <div>
              <h2 class="text-lg font-semibold text-slate-950">
                {metadata_heading(@book)}
              </h2>
              <p class="mt-1 text-sm leading-6 text-slate-600">
                {metadata_intro(@book)}
              </p>
            </div>
          </div>

          <.form
            for={
              to_form(
                %{"query" => @metadata_query, "provider" => @metadata_provider},
                as: :metadata
              )
            }
            id="metadata-search-form"
            phx-submit="search_metadata"
            class="mt-5"
          >
            <.input
              field={
                to_form(
                  %{"query" => @metadata_query, "provider" => @metadata_provider},
                  as: :metadata
                )[:provider]
              }
              type="select"
              label="Metadata source"
              options={@metadata_provider_options}
            />
            <.input
              field={
                to_form(
                  %{"query" => @metadata_query, "provider" => @metadata_provider},
                  as: :metadata
                )[:query]
              }
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
            :if={@metadata_message}
            id="metadata-message"
            class={[
              "mt-4 rounded-xl px-4 py-3 text-sm leading-6",
              @metadata_status == :error && "bg-red-50 text-red-800",
              @metadata_status != :error && "bg-white text-slate-700 ring-1 ring-slate-200"
            ]}
          >
            {@metadata_message}
          </p>

          <div :if={@metadata_results != []} id="metadata-results" class="mt-5 space-y-3">
            <article
              :for={result <- @metadata_results}
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
                <button
                  type="button"
                  phx-click="select_metadata"
                  phx-value-id={result.id}
                  class="mt-3 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-amber-100 px-4 text-sm font-semibold text-amber-950 transition hover:bg-amber-200 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 sm:w-auto"
                >
                  <.icon name="hero-arrow-down-tray" class="size-4" />
                  {metadata_select_label(@book)}
                </button>
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
            <h3 class="mt-2 text-lg font-semibold text-slate-950">
              {@pending_metadata.title}
            </h3>
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

        <.form
          for={@form}
          id={form_id(@book)}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8"
        >
          <input type="hidden" name={@form[:cover_url].name} value={@form[:cover_url].value} />
          <input
            type="hidden"
            name={@form[:cover_provider].name}
            value={@form[:cover_provider].value}
          />
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
              :if={use_calculated_estimate?(@book, @form)}
              id="calculated-estimated-words"
              class="rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-5"
            >
              <input
                type="hidden"
                name={@form[:estimated_words].name}
                value={@form[:estimated_words].value}
              />
              <input
                type="hidden"
                name={@form[:estimated_words_mode].name}
                value="calculated"
              />
              <p class="text-sm font-medium text-slate-600">Estimated Total Words</p>
              <p class="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
                {BookFormat.number(@form[:estimated_words].value)}
              </p>
              <p class="mt-1 flex items-center gap-1.5 text-xs leading-5 text-slate-500">
                <.icon name="hero-calculator" class="size-4" /> Using 250 words per page
              </p>
            </div>

            <div :if={!use_calculated_estimate?(@book, @form)}>
              <input
                type="hidden"
                name={@form[:estimated_words_mode].name}
                value={@form[:estimated_words_mode].value || "manual"}
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
                Enter a total directly or use the helper below.
              </p>
            </div>
          </div>

          <section
            id="word-estimate-helper"
            class="rounded-2xl border border-slate-200 bg-slate-50/70 p-4 sm:p-5"
          >
            <div class="flex items-start gap-3">
              <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-white text-slate-600 ring-1 ring-slate-200">
                <.icon name="hero-calculator" class="size-5" />
              </span>
              <div>
                <h2 class="font-semibold text-slate-900">Word Estimate Helper</h2>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Paste a representative sample to estimate the whole book. The sample is never saved.
                </p>
              </div>
            </div>

            <div class="mt-5 space-y-5">
              <.input
                field={@estimator_form[:sample_text]}
                type="textarea"
                label="Sample text"
                placeholder="Paste a representative passage from the book..."
                rows="8"
              />

              <div
                id="sample-word-count"
                class="flex items-center justify-between rounded-xl bg-white px-4 py-3 ring-1 ring-slate-200"
              >
                <span class="text-sm font-medium text-slate-600">Words in sample</span>
                <strong class="text-lg font-semibold text-slate-950">
                  {BookFormat.number(@estimator_result.sample_words)}
                </strong>
              </div>

              <div class="grid gap-4 sm:grid-cols-3">
                <.input
                  field={@estimator_form[:sample_units]}
                  type="number"
                  label="Sample unit count"
                  placeholder="5"
                  min="0.01"
                  step="any"
                  inputmode="decimal"
                />
                <.input
                  field={@estimator_form[:total_units]}
                  type="number"
                  label="Total unit count"
                  placeholder="180"
                  min="0.01"
                  step="any"
                  inputmode="decimal"
                />
                <.input
                  field={@estimator_form[:unit_type]}
                  type="select"
                  label="Unit type"
                  options={@unit_options}
                />
              </div>

              <p
                :if={@estimator_result.message}
                id="word-estimate-error"
                class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800"
              >
                {@estimator_result.message}
              </p>

              <div
                :if={@estimator_result.estimated_words}
                id="sample-estimated-words"
                class="rounded-xl border border-amber-200 bg-amber-50 p-4"
              >
                <p class="text-sm font-medium text-amber-900/70">Estimated total words</p>
                <p class="mt-1 text-2xl font-semibold tracking-tight text-amber-950">
                  {BookFormat.number(@estimator_result.estimated_words)}
                </p>
              </div>

              <button
                id="apply-word-estimate"
                type="button"
                phx-click="apply_word_estimate"
                disabled={is_nil(@estimator_result.estimated_words)}
                class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 disabled:cursor-not-allowed disabled:bg-slate-300 sm:w-auto"
              >
                <.icon name="hero-arrow-up-tray" class="size-4" /> Apply Estimate
              </button>
            </div>
          </section>

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
              <.icon name="hero-book-open" class="size-5" /> {save_label(@book)}
            </.button>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp save_book(socket, params) do
    case persist_book(socket.assigns.book, socket.assigns.reading_log, params) do
      {:ok, book} ->
        {:noreply,
         socket
         |> put_flash(:info, save_message(socket.assigns.book, book))
         |> push_navigate(to: save_path(socket.assigns.book, book))}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't save this book. Check the details and try again.")
         |> assign(:form, to_form(params, as: :book, action: :validate))}
    end
  end

  defp persist_book(nil, reading_log, params) do
    Library.add_book(reading_log.id, params["title"], book_attributes(params))
  end

  defp persist_book(book, _reading_log, params) do
    Library.edit_book(book, Map.put(book_attributes(params), :title, params["title"]))
  end

  defp book_attributes(params) do
    params
    |> Map.take([
      "author",
      "page_count",
      "estimated_words",
      "cover_url",
      "cover_provider",
      "cover_id",
      "difficulty_label",
      "status",
      "started_on",
      "finished_on",
      "notes"
    ])
    |> Map.new(fn {key, value} -> {String.to_existing_atom(key), empty_to_nil(value)} end)
  end

  defp sync_estimated_words(params, %CiBookTracker.Library.Book{}) do
    Map.put(params, "estimated_words_mode", "manual")
  end

  defp sync_estimated_words(params, nil) do
    if params["estimated_words_mode"] == "sample" do
      params
    else
      case parse_positive_integer(params["page_count"]) do
        {:ok, page_count} ->
          params
          |> Map.put("estimated_words", Integer.to_string(page_count * 250))
          |> Map.put("estimated_words_mode", "calculated")

        :error ->
          params
          |> maybe_clear_calculated_estimate()
          |> Map.put("estimated_words_mode", "manual")
      end
    end
  end

  defp maybe_clear_calculated_estimate(%{"estimated_words_mode" => "calculated"} = params),
    do: Map.put(params, "estimated_words", "")

  defp maybe_clear_calculated_estimate(params), do: params

  defp put_if_present(params, _key, nil), do: params
  defp put_if_present(params, key, value), do: Map.put(params, key, to_string(value))

  defp put_metadata_estimate(params, nil), do: params

  defp put_metadata_estimate(params, page_count) do
    params
    |> Map.put("estimated_words", Integer.to_string(page_count * 250))
    |> Map.put("estimated_words_mode", "manual")
  end

  defp valid_page_count?(value), do: match?({:ok, _page_count}, parse_positive_integer(value))

  defp use_calculated_estimate?(nil, form) do
    form[:estimated_words_mode].value != "sample" && valid_page_count?(form[:page_count].value)
  end

  defp use_calculated_estimate?(_book, _form), do: false

  defp update_estimator(socket, params) do
    result =
      if estimator_blank?(params) do
        %{sample_words: 0, estimated_words: nil, message: nil}
      else
        case WordEstimator.evaluate(params) do
          {:ok, result} -> Map.put(result, :message, nil)
          {:error, result} -> Map.put(result, :estimated_words, nil)
        end
      end

    socket
    |> assign(:estimator_form, to_form(Map.merge(@estimator_params, params), as: :estimator))
    |> assign(:estimator_result, result)
  end

  defp estimator_blank?(params) do
    Enum.all?(["sample_text", "sample_units", "total_units"], &blank?(params[&1]))
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {page_count, ""} when page_count > 0 -> {:ok, page_count}
      _other -> :error
    end
  end

  defp parse_positive_integer(_value), do: :error

  defp normalize_params(params) do
    params = Map.merge(@empty_params, params)

    Enum.reduce(["title", "author", "difficulty_label"], params, fn key, params ->
      Map.update!(params, key, &String.trim/1)
    end)
  end

  defp empty_to_nil(value) when value in [nil, ""], do: nil
  defp empty_to_nil(value), do: value

  defp blank?(value), do: value in [nil, ""]

  defp active_reading_log(session) do
    id = session["active_reading_log_id"] || session["auto_open_reading_log_id"]

    case id && Library.get_reading_log(id) do
      {:ok, reading_log} -> reading_log
      _missing -> nil
    end
  end

  defp load_book(:new, _params, _reading_log), do: {:ok, nil}

  defp load_book(:edit, %{"id" => id}, reading_log) do
    case Library.get_book(id) do
      {:ok, %{reading_log_id: reading_log_id} = book} when reading_log_id == reading_log.id ->
        {:ok, book}

      _missing ->
        {:error, :not_found}
    end
  end

  defp form_params(nil), do: @empty_params

  defp form_params(book) do
    %{
      "title" => book.title || "",
      "author" => book.author || "",
      "page_count" => input_value(book.page_count),
      "estimated_words" => input_value(book.estimated_words),
      "estimated_words_mode" => "manual",
      "cover_url" => book.cover_url || "",
      "cover_provider" => book.cover_provider || "",
      "cover_id" => input_value(book.cover_id),
      "difficulty_label" => book.difficulty_label || "",
      "status" => Atom.to_string(book.status),
      "started_on" => input_value(book.started_on),
      "finished_on" => input_value(book.finished_on),
      "notes" => book.notes || ""
    }
  end

  defp metadata_refresh?(nil, _params), do: false
  defp metadata_refresh?(_book, %{"metadata" => "refresh"}), do: true
  defp metadata_refresh?(_book, _params), do: false

  defp initial_metadata_query(book, true) do
    [book.title, book.author]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  defp initial_metadata_query(_book, _metadata_refresh?), do: ""

  defp input_value(nil), do: ""
  defp input_value(%Date{} = value), do: Date.to_iso8601(value)
  defp input_value(value), do: to_string(value)

  defp page_title(:new), do: "Add book"
  defp page_title(:edit), do: "Edit book"
  defp form_heading(nil), do: "Add a book"
  defp form_heading(_book), do: "Edit book"
  defp form_intro(nil), do: "Start with what you know. Everything except the title is optional."
  defp form_intro(_book), do: "Update the details and reading history for this book."

  defp metadata_heading(nil), do: "Find Metadata"
  defp metadata_heading(_book), do: "Refresh Metadata"

  defp metadata_intro(nil), do: "Optional. Find a book, then review the details before saving."

  defp metadata_intro(_book),
    do:
      "Search for a cover and missing book details without replacing your saved title or author."

  defp metadata_select_label(nil), do: "Use this book"
  defp metadata_select_label(_book), do: "Use this book"

  defp save_label(nil), do: "Save Book"
  defp save_label(_book), do: "Save Changes"
  defp form_id(nil), do: "add-book-form"
  defp form_id(_book), do: "edit-book-form"
  defp back_path(nil), do: ~p"/dashboard"
  defp back_path(book), do: ~p"/books/#{book.id}"
  defp save_path(nil, _book), do: ~p"/dashboard"
  defp save_path(_existing_book, book), do: ~p"/books/#{book.id}"
  defp save_message(nil, book), do: "#{book.title} was added to your reading log."
  defp save_message(_existing_book, book), do: "#{book.title} was updated."
  defp missing_message(:new), do: "Create a reading log before adding a book."
  defp missing_message(:edit), do: "That book isn't available in the active reading log."
  defp missing_path(nil), do: ~p"/"
  defp missing_path(_reading_log), do: ~p"/dashboard"

  defp metadata_provider("google_books"), do: :google_books
  defp metadata_provider("hardcover"), do: :hardcover
  defp metadata_provider("all"), do: :all
  defp metadata_provider(_provider), do: :open_library

  defp metadata_provider_label(:google_books), do: "Google Books"
  defp metadata_provider_label(:hardcover), do: "Hardcover"
  defp metadata_provider_label(_provider), do: "Open Library"

  defp metadata_error_message(:timeout),
    do: "The metadata source took too long to respond. Please try again."

  defp metadata_error_message(:quota_exceeded),
    do:
      "The metadata provider's request limit has been reached. Configure GOOGLE_BOOKS_API_KEY, add a key in Settings, or use another source."

  defp metadata_error_message(:missing_token),
    do: "Hardcover requires an API token. Add one in Settings before searching."

  defp metadata_error_message(:invalid_token),
    do: "Hardcover rejected the configured API token. Update it in Settings."

  defp metadata_error_message(:provider_disabled),
    do: "That metadata provider is disabled. You can enable it in Settings."

  defp metadata_error_message(:graphql_error),
    do: "Hardcover could not complete that search. Try a different query or another source."

  defp metadata_error_message(_reason),
    do: "The metadata source is unavailable right now. You can keep entering the book manually."

  defp metadata_provider_options do
    providers = MetadataProviders.enabled_search_providers()

    options =
      Enum.map(providers, fn
        :open_library -> {"Open Library", "open_library"}
        :google_books -> {"Google Books", "google_books"}
        :hardcover -> {"Hardcover", "hardcover"}
      end)

    if length(providers) > 1, do: options ++ [{"All providers", "all"}], else: options
  end
end
