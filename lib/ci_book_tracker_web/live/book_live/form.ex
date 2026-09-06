defmodule CiBookTrackerWeb.BookLive.Form do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCover
  alias CiBookTracker.Library.BookMetadata
  alias CiBookTracker.Settings.MetadataProviders
  alias CiBookTrackerWeb.BookLive.{FormComponents, FormParams}
  alias CiBookTrackerWeb.ReadingLogSession
  alias CiBookTrackerWeb.WordEstimatorForm

  @status_options [
    {"Want to read", "want_to_read"},
    {"In progress", "in_progress"},
    {"Finished", "finished"},
    {"Abandoned", "abandoned"}
  ]

  @impl true
  def mount(params, session, socket) do
    reading_log = ReadingLogSession.resolve_or_nil(session)

    with %{} <- reading_log,
         {:ok, book} <- load_book(socket.assigns.live_action, params, reading_log) do
      metadata_refresh? = metadata_refresh?(book, params)

      {:ok,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:reading_log, reading_log)
       |> assign(:book, book)
       |> assign(:status_options, @status_options)
       |> update_estimator(%{})
       |> assign(:metadata_provider_options, metadata_provider_options())
       |> assign(:metadata_provider, "open_library")
       |> assign(:metadata_refresh?, metadata_refresh?)
       |> assign(:metadata_query, FormParams.initial_metadata_query(book, metadata_refresh?))
       |> assign(:metadata_results, [])
       |> assign(:metadata_status, :idle)
       |> assign(:metadata_message, nil)
       |> assign(:pending_metadata, nil)
       |> assign(:selected_cover_result_id, nil)
       |> assign(:form, to_form(FormParams.initial(book), as: :book))
       |> allow_upload(:cover_art,
         accept: ~w(.jpg .jpeg .png .webp .gif),
         max_entries: 1,
         max_file_size: 8_000_000
       )}
    else
      _missing ->
        {:ok,
         socket
         |> put_flash(:error, missing_message(socket.assigns.live_action))
         |> push_navigate(to: missing_path(reading_log))}
    end
  end

  @impl true
  def handle_event("validate", %{"book" => params} = event, socket) do
    params = FormParams.sync_estimated_words(params)

    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :book))
     |> update_estimator(event["estimator"])}
  end

  def handle_event("enter_word_estimate", _params, socket) do
    params = Map.put(socket.assigns.form.params, "estimated_words_mode", "manual")
    {:noreply, assign(socket, :form, to_form(params, as: :book))}
  end

  def handle_event("apply_word_estimate", _params, socket) do
    case socket.assigns.estimator_result.estimated_words do
      estimate when is_integer(estimate) and estimate > 0 ->
        params =
          socket.assigns.form.params
          |> Map.put("estimated_words", Integer.to_string(estimate))
          |> Map.put("estimated_words_mode", "manual")

        {:noreply, assign(socket, :form, to_form(params, as: :book))}

      _invalid ->
        {:noreply, socket}
    end
  end

  def handle_event("save", %{"book" => params}, socket) do
    params =
      params
      |> FormParams.normalize()
      |> FormParams.sync_estimated_words()

    if FormParams.blank?(params["title"]) do
      form =
        to_form(params,
          as: :book,
          action: :validate,
          errors: [title: {"can't be blank", []}]
        )

      {:noreply, assign(socket, :form, form)}
    else
      prepare_and_save_book(socket, params)
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
           |> assign(:metadata_message, message)
           |> assign(:selected_cover_result_id, nil)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:metadata_provider, Atom.to_string(provider))
           |> assign(:metadata_query, query)
           |> assign(:metadata_results, [])
           |> assign(:metadata_status, :error)
           |> assign(:metadata_message, metadata_error_message(reason))
           |> assign(:selected_cover_result_id, nil)}
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
         |> assign(:selected_cover_result_id, nil)
         |> assign(:metadata_status, :review)
         |> assign(
           :metadata_message,
           "Review the metadata below. Nothing changes until you apply it."
         )}

      result ->
        params =
          FormParams.apply_metadata(socket.assigns.form.params, result, :new)

        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :book))
         |> assign(:selected_cover_result_id, nil)
         |> assign(:metadata_status, :selected)
         |> assign(:metadata_message, "Metadata added to the form. Review it before saving.")}
    end
  end

  def handle_event("select_cover", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.metadata_results, &(&1.id == id && &1.cover_url)) do
      nil ->
        {:noreply, socket}

      result ->
        params = FormParams.apply_cover(socket.assigns.form.params, result)

        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :book))
         |> assign(:pending_metadata, nil)
         |> assign(:selected_cover_result_id, result.id)
         |> assign(:metadata_status, :selected)
         |> assign(:metadata_message, nil)
         |> put_flash(:info, "Cover added to the form. Save the book to keep this change.")}
    end
  end

  def handle_event("apply_metadata", _params, socket) do
    case socket.assigns.pending_metadata do
      nil ->
        {:noreply, socket}

      result ->
        params =
          FormParams.apply_metadata(socket.assigns.form.params, result, :edit)

        {:noreply,
         socket
         |> assign(:form, to_form(params, as: :book))
         |> assign(:pending_metadata, nil)
         |> assign(:selected_cover_result_id, nil)
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
     |> assign(:selected_cover_result_id, nil)
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

        <FormComponents.metadata_search
          :if={is_nil(@book) || @metadata_refresh?}
          book={@book}
          query={@metadata_query}
          provider={@metadata_provider}
          provider_options={@metadata_provider_options}
          results={@metadata_results}
          status={@metadata_status}
          message={@metadata_message}
          pending_metadata={@pending_metadata}
          selected_cover_result_id={@selected_cover_result_id}
          book_form_id={form_id(@book)}
          save_label={save_label(@book)}
        />

        <.form
          for={@form}
          id={form_id(@book)}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8"
        >
          <FormComponents.book_fields
            form={@form}
            book={@book}
            estimator_form={@estimator_form}
            estimator_result={@estimator_result}
            uploads={@uploads}
            status_options={@status_options}
            save_label={save_label(@book)}
          />
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp prepare_and_save_book(socket, params) do
    case store_cover(socket, params) do
      {:ok, params} ->
        save_book(socket, params)

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, cover_error_message(reason))
         |> assign(:form, to_form(params, as: :book, action: :validate))}
    end
  end

  defp store_cover(socket, params) do
    case consume_uploaded_entries(socket, :cover_art, fn %{path: path}, entry ->
           {:ok, BookCover.store_upload(path, entry.client_name)}
         end) do
      [{:ok, %{cover_path: cover_path}}] ->
        {:ok,
         params
         |> Map.put("cover_path", cover_path)
         |> Map.put("cover_url", "")
         |> Map.put("cover_provider", "local")
         |> Map.put("cover_id", "")}

      [] ->
        store_cover_url(params)

      [{:error, reason} | _rest] ->
        {:error, reason}
    end
  end

  defp store_cover_url(params) do
    case params["cover_image_url"] |> to_string() |> String.trim() do
      "" ->
        {:ok, params}

      cover_url ->
        case BookCover.store_url(cover_url) do
          {:ok, %{cover_path: cover_path, cover_url: stored_url}} ->
            {:ok,
             params
             |> Map.put("cover_path", cover_path)
             |> Map.put("cover_url", stored_url)}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp save_book(socket, params) do
    case persist_book(socket.assigns.book, socket.assigns.reading_log, params) do
      {:ok, book} ->
        {:noreply,
         socket
         |> put_flash(:info, save_message(socket.assigns.book, book))
         |> push_navigate(to: save_path(socket.assigns.book, book))}

      {:error, _error} ->
        cleanup_unpersisted_cover(socket.assigns.book, params)

        {:noreply,
         socket
         |> put_flash(:error, "We couldn't save this book. Check the details and try again.")
         |> assign(:form, to_form(params, as: :book, action: :validate))}
    end
  end

  defp persist_book(nil, reading_log, params) do
    book_attributes = FormParams.book_attributes(params)
    cover_attributes = FormParams.cover_attributes(params)

    if is_nil(cover_attributes.cover_path) do
      Library.add_book(reading_log.id, params["title"], book_attributes)
    else
      Library.add_book_with_cover(
        reading_log.id,
        params["title"],
        Map.merge(book_attributes, cover_attributes)
      )
    end
  end

  defp persist_book(book, _reading_log, params) do
    book_attributes =
      params
      |> FormParams.book_attributes()
      |> Map.put(:title, params["title"])

    cover_attributes = FormParams.cover_attributes(params)

    cond do
      !FormParams.cover_changed?(book, cover_attributes) ->
        Library.edit_book(book, book_attributes)

      is_nil(cover_attributes.cover_path) ->
        Library.edit_book_without_cover(book, book_attributes)

      true ->
        BookCover.edit(book, Map.merge(book_attributes, cover_attributes))
    end
  end

  defp cleanup_unpersisted_cover(book, %{"cover_path" => cover_path})
       when is_binary(cover_path) and cover_path != "" do
    if is_nil(book) || book.cover_path != cover_path, do: BookCover.remove(cover_path)
  end

  defp cleanup_unpersisted_cover(_book, _params), do: :ok

  defp update_estimator(socket, nil), do: socket

  defp update_estimator(socket, params) do
    {form, result} = WordEstimatorForm.build(params)

    socket
    |> assign(:estimator_form, form)
    |> assign(:estimator_result, result)
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

  defp metadata_refresh?(nil, _params), do: false
  defp metadata_refresh?(_book, %{"metadata" => "refresh"}), do: true
  defp metadata_refresh?(_book, _params), do: false

  defp page_title(:new), do: "Add book"
  defp page_title(:edit), do: "Edit book"
  defp form_heading(nil), do: "Add a book"
  defp form_heading(_book), do: "Edit book"
  defp form_intro(nil), do: "Start with what you know. Everything except the title is optional."
  defp form_intro(_book), do: "Update the details and reading history for this book."

  defp cover_error_message(:invalid_url), do: "Enter a valid http or https cover image URL."
  defp cover_error_message(:download_failed), do: "We couldn't download that cover image."
  defp cover_error_message(:timeout), do: "The cover image took too long to download."
  defp cover_error_message(:unsupported_type), do: "Choose a JPG, PNG, WebP, or GIF cover image."
  defp cover_error_message(:too_large), do: "Choose a cover image smaller than 8 MB."
  defp cover_error_message(:empty), do: "Choose a cover image that is not empty."
  defp cover_error_message(_reason), do: "We couldn't store that cover image."

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
