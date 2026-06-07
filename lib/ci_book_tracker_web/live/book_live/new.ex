defmodule CiBookTrackerWeb.BookLive.New do
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
  def mount(_params, _session, socket) do
    reading_log =
      Library.list_reading_logs!(query: [sort: [inserted_at: :asc], limit: 1])
      |> List.first()

    if reading_log do
      {:ok,
       socket
       |> assign(:page_title, "Add book")
       |> assign(:reading_log, reading_log)
       |> assign(:status_options, @status_options)
       |> assign(:form, to_form(@empty_params, as: :book))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Create a reading log before adding a book.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"book" => params}, socket) do
    params = sync_estimated_words(params)
    {:noreply, assign(socket, :form, to_form(params, as: :book))}
  end

  def handle_event("save", %{"book" => params}, socket) do
    params =
      params
      |> sync_estimated_words()
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
            navigate={~p"/"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to dashboard
          </.link>

          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            {@reading_log.name}
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Add a book
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            Start with what you know. Everything except the title is optional.
          </p>
        </header>

        <.form
          for={@form}
          id="add-book-form"
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
              :if={valid_page_count?(@form[:page_count].value)}
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

            <div :if={!valid_page_count?(@form[:page_count].value)}>
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
              <p class="-mt-2 text-xs leading-5 text-slate-500">
                Enter the total word estimate when the page count is unknown.
              </p>
            </div>
          </div>

          <.input
            field={@form[:difficulty_label]}
            label="Difficulty"
            placeholder="Beginner, intermediate, advanced..."
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
              <.icon name="hero-book-open" class="size-5" /> Save Book
            </.button>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp save_book(socket, params) do
    case Library.add_book(
           socket.assigns.reading_log.id,
           params["title"],
           book_attributes(params)
         ) do
      {:ok, book} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{book.title} was added to your reading log.")
         |> push_navigate(to: ~p"/")}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't save this book. Check the details and try again.")
         |> assign(:form, to_form(params, as: :book, action: :validate))}
    end
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

  defp sync_estimated_words(params) do
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
