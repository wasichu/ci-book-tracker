defmodule CiBookTrackerWeb.ReadingLogLive.New do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogFormat

  @empty_params %{
    "name" => "",
    "language_code" => "es",
    "goal_amount" => "",
    "goal_unit" => "thousand",
    "auto_open" => "false"
  }

  @goal_units [
    {"Words", "words"},
    {"Thousand words", "thousand"},
    {"Million words", "million"}
  ]

  @impl true
  def mount(params, _session, socket) do
    case load_reading_log(socket.assigns.live_action, params) do
      {:ok, reading_log} ->
        {:ok,
         socket
         |> assign(:page_title, page_title(reading_log))
         |> assign(:reading_log, reading_log)
         |> assign(:return_path, return_path(params))
         |> assign(:language_options, ReadingLogFormat.language_options())
         |> assign(:goal_units, @goal_units)
         |> assign(:form, to_form(form_params(reading_log), as: :reading_log))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "That reading log could not be found.")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"reading_log" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(complete_params(params), as: :reading_log))}
  end

  def handle_event("save", %{"reading_log" => params}, socket) do
    params = normalize_params(params)

    errors =
      []
      |> maybe_add_name_error(params)
      |> maybe_add_goal_error(params)

    case errors do
      [] -> save_reading_log(socket, params)
      errors -> {:noreply, assign(socket, :form, error_form(params, errors))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id={page_id(@reading_log)} class="space-y-7">
        <header>
          <.link
            navigate={@return_path}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>

          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            {eyebrow(@reading_log)}
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            {heading(@reading_log)}
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            {intro(@reading_log)}
          </p>
        </header>

        <.form
          for={@form}
          id={form_id(@reading_log)}
          phx-change="validate"
          phx-submit="save"
          class="space-y-6 rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8"
        >
          <.input
            field={@form[:name]}
            label="Name"
            placeholder="Spanish reading"
            required
            autocomplete="off"
          />

          <.input
            field={@form[:language_code]}
            type="select"
            label="Language"
            options={@language_options}
            required
          />

          <fieldset>
            <legend class="text-sm font-medium text-slate-700">Word goal</legend>
            <div class="mt-1.5 grid grid-cols-[minmax(0,1fr)_minmax(9rem,0.8fr)] gap-3">
              <.input
                field={@form[:goal_amount]}
                type="number"
                label="Goal amount"
                placeholder="500"
                min="0.001"
                step="any"
                inputmode="decimal"
              />
              <.input
                field={@form[:goal_unit]}
                type="select"
                label="Unit"
                options={@goal_units}
              />
            </div>
            <p class="-mt-2 text-xs leading-5 text-slate-500">
              Optional.
            </p>
          </fieldset>

          <div
            :if={is_nil(@reading_log)}
            class="rounded-2xl bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-950"
          >
            <div class="flex gap-3">
              <.icon name="hero-light-bulb" class="mt-1 size-4 shrink-0 text-amber-700" />
              <p>
                Pick a goal that feels useful, not perfect. You can start tracking without one.
              </p>
            </div>
          </div>

          <div
            :if={is_nil(@reading_log)}
            class="rounded-2xl border border-slate-200 bg-slate-50/70 p-4"
          >
            <.input
              field={@form[:auto_open]}
              type="checkbox"
              label="Automatically open this log next time"
            />
            <p class="-mt-2 pl-7 text-xs leading-5 text-slate-500">
              You can always use Switch Log from the dashboard to choose another shelf.
            </p>
          </div>

          <div class="border-t border-slate-100 pt-6">
            <.button
              id="save-reading-log"
              type="submit"
              variant="primary"
              phx-disable-with={saving_label(@reading_log)}
              class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-amber-700 px-6 text-base font-semibold text-white shadow-lg shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0 disabled:translate-y-0"
            >
              <.icon name="hero-language" class="size-5" /> {save_label(@reading_log)}
            </.button>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp save_reading_log(socket, params) do
    case persist_reading_log(socket.assigns.reading_log, params) do
      {:ok, reading_log} ->
        finish_save(socket, reading_log, params)

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't save this reading log. Check the details and try again."
         )
         |> assign(:form, to_form(params, as: :reading_log, action: :validate))}
    end
  end

  defp persist_reading_log(nil, params) do
    Library.create_reading_log(
      params["name"],
      params["language_code"],
      word_goal(params)
    )
  end

  defp persist_reading_log(reading_log, params) do
    Library.edit_reading_log(reading_log, %{
      name: params["name"],
      language_code: params["language_code"],
      word_goal: word_goal(params)
    })
  end

  defp finish_save(%{assigns: %{reading_log: nil}} = socket, reading_log, params) do
    {:noreply,
     socket
     |> put_flash(:info, "#{reading_log.name} is ready.")
     |> redirect(to: ~p"/reading-logs/#{reading_log.id}/open?#{[auto_open: params["auto_open"]]}")}
  end

  defp finish_save(socket, reading_log, _params) do
    {:noreply,
     socket
     |> put_flash(:info, "#{reading_log.name} was updated.")
     |> push_navigate(to: socket.assigns.return_path)}
  end

  defp normalize_params(params) do
    params = complete_params(params)

    params
    |> Map.update!("name", &String.trim/1)
    |> Map.update!("language_code", fn language_code ->
      language_code
      |> String.trim()
      |> String.downcase()
    end)
  end

  defp complete_params(params), do: Map.merge(@empty_params, params)

  defp maybe_add_name_error(errors, %{"name" => ""}),
    do: [{:name, {"can't be blank", []}} | errors]

  defp maybe_add_name_error(errors, _params), do: errors

  defp maybe_add_goal_error(errors, params) do
    case parse_goal(params) do
      {:ok, _word_goal} -> errors
      :error -> [{:goal_amount, {"must be a positive number", []}} | errors]
    end
  end

  defp error_form(params, errors) do
    to_form(params, as: :reading_log, action: :validate, errors: errors)
  end

  defp word_goal(params) do
    {:ok, word_goal} = parse_goal(params)
    word_goal
  end

  defp parse_goal(%{"goal_amount" => amount}) when amount in [nil, ""], do: {:ok, nil}

  defp parse_goal(%{"goal_amount" => amount, "goal_unit" => unit}) do
    multiplier = %{"words" => 1, "thousand" => 1_000, "million" => 1_000_000}

    with {number, ""} <- Float.parse(amount),
         true <- number > 0,
         multiplier when is_integer(multiplier) <- multiplier[unit],
         word_goal <- round(number * multiplier),
         true <- word_goal > 0 do
      {:ok, word_goal}
    else
      _invalid -> :error
    end
  end

  defp load_reading_log(:new, _params), do: {:ok, nil}

  defp load_reading_log(:edit, %{"id" => id}) do
    case Library.get_reading_log(id) do
      {:ok, reading_log} -> {:ok, reading_log}
      _error -> {:error, :not_found}
    end
  end

  defp form_params(nil), do: @empty_params

  defp form_params(reading_log) do
    {goal_amount, goal_unit} = goal_fields(reading_log.word_goal)

    %{
      "name" => reading_log.name,
      "language_code" => reading_log.language_code,
      "goal_amount" => goal_amount,
      "goal_unit" => goal_unit,
      "auto_open" => "false"
    }
  end

  defp goal_fields(nil), do: {"", "thousand"}

  defp goal_fields(word_goal) when word_goal >= 1_000_000 and rem(word_goal, 1_000) == 0,
    do: {format_goal_amount(word_goal / 1_000_000), "million"}

  defp goal_fields(word_goal) when rem(word_goal, 1_000) == 0,
    do: {format_goal_amount(word_goal / 1_000), "thousand"}

  defp goal_fields(word_goal), do: {Integer.to_string(word_goal), "words"}

  defp format_goal_amount(amount) when trunc(amount) == amount,
    do: Integer.to_string(trunc(amount))

  defp format_goal_amount(amount), do: to_string(amount)

  defp return_path(%{"from" => "dashboard"}), do: ~p"/dashboard"
  defp return_path(_params), do: ~p"/"

  defp page_title(nil), do: "Create reading log"
  defp page_title(_reading_log), do: "Edit reading log"
  defp page_id(nil), do: "create-reading-log-page"
  defp page_id(_reading_log), do: "edit-reading-log-page"
  defp form_id(nil), do: "create-reading-log-form"
  defp form_id(_reading_log), do: "edit-reading-log-form"
  defp eyebrow(nil), do: "Start your shelf"
  defp eyebrow(_reading_log), do: "Log settings"
  defp heading(nil), do: "Create a reading log"
  defp heading(_reading_log), do: "Edit reading log"

  defp intro(nil), do: "Choose the language you are reading in. A word goal is optional."

  defp intro(_reading_log),
    do: "Update this log's name, language, or optional word goal."

  defp save_label(nil), do: "Create Reading Log"
  defp save_label(_reading_log), do: "Save Changes"
  defp saving_label(nil), do: "Creating..."
  defp saving_label(_reading_log), do: "Saving..."
end
