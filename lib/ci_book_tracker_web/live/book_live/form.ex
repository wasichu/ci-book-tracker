defmodule CiBookTrackerWeb.BookLive.Form do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library

  @empty_params %{
    "title" => "",
    "author" => "",
    "page_count" => "",
    "estimated_words" => "",
    "estimated_words_mode" => "manual",
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

  @impl true
  def mount(params, session, socket) do
    reading_log = active_reading_log(session)

    with %{} <- reading_log,
         {:ok, book} <- load_book(socket.assigns.live_action, params, reading_log) do
      {:ok,
       socket
       |> assign(:page_title, page_title(socket.assigns.live_action))
       |> assign(:reading_log, reading_log)
       |> assign(:book, book)
       |> assign(:status_options, @status_options)
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
  def handle_event("validate", %{"book" => params}, socket) do
    params = sync_estimated_words(params, socket.assigns.book)
    {:noreply, assign(socket, :form, to_form(params, as: :book))}
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

        <.form
          for={@form}
          id={form_id(@book)}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8"
        >
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
              :if={is_nil(@book) && valid_page_count?(@form[:page_count].value)}
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
                {format_number(@form[:estimated_words].value)}
              </p>
              <p class="mt-1 flex items-center gap-1.5 text-xs leading-5 text-slate-500">
                <.icon name="hero-calculator" class="size-4" /> Using 250 words per page
              </p>
            </div>

            <div :if={@book || !valid_page_count?(@form[:page_count].value)}>
              <input
                type="hidden"
                name={@form[:estimated_words_mode].name}
                value="manual"
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
                Enter the total word estimate when the page count is unknown.
              </p>
            </div>
          </div>

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

  defp maybe_clear_calculated_estimate(%{"estimated_words_mode" => "calculated"} = params),
    do: Map.put(params, "estimated_words", "")

  defp maybe_clear_calculated_estimate(params), do: params

  defp valid_page_count?(value), do: match?({:ok, _page_count}, parse_positive_integer(value))

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
      "difficulty_label" => book.difficulty_label || "",
      "status" => Atom.to_string(book.status),
      "started_on" => input_value(book.started_on),
      "finished_on" => input_value(book.finished_on),
      "notes" => book.notes || ""
    }
  end

  defp input_value(nil), do: ""
  defp input_value(%Date{} = value), do: Date.to_iso8601(value)
  defp input_value(value), do: to_string(value)

  defp page_title(:new), do: "Add book"
  defp page_title(:edit), do: "Edit book"
  defp form_heading(nil), do: "Add a book"
  defp form_heading(_book), do: "Edit book"
  defp form_intro(nil), do: "Start with what you know. Everything except the title is optional."
  defp form_intro(_book), do: "Update the details and reading history for this book."

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

  defp format_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> format_number(number)
      _other -> value
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end
