defmodule CiBookTrackerWeb.ReadingLogLive.New do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library

  @empty_params %{
    "name" => "",
    "language_code" => "es",
    "word_goal" => ""
  }

  @impl true
  def mount(_params, _session, socket) do
    if Library.list_reading_logs!(query: [limit: 1]) == [] do
      {:ok,
       socket
       |> assign(:page_title, "Create reading log")
       |> assign(:form, to_form(@empty_params, as: :reading_log))}
    else
      {:ok,
       socket
       |> put_flash(:info, "Your reading log is ready.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"reading_log" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(complete_params(params), as: :reading_log))}
  end

  def handle_event("save", %{"reading_log" => params}, socket) do
    params = normalize_params(params)

    if params["name"] == "" do
      form =
        to_form(params,
          as: :reading_log,
          action: :validate,
          errors: [name: {"can't be blank", []}]
        )

      {:noreply, assign(socket, :form, form)}
    else
      save_reading_log(socket, params)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="create-reading-log-page" class="space-y-7">
        <header>
          <.link
            navigate={~p"/"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>

          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Start your shelf
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Create a reading log
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            Choose the language you are reading in. A word goal is optional.
          </p>
        </header>

        <.form
          for={@form}
          id="create-reading-log-form"
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
            label="Language code"
            placeholder="es"
            required
            autocomplete="off"
            maxlength="10"
          />

          <div>
            <.input
              field={@form[:word_goal]}
              type="number"
              label="Word goal"
              placeholder="100000"
              min="1"
              inputmode="numeric"
            />
            <p class="-mt-2 text-xs leading-5 text-slate-500">
              Optional. You can start tracking books without setting a target.
            </p>
          </div>

          <div class="border-t border-slate-100 pt-6">
            <.button
              id="save-reading-log"
              type="submit"
              variant="primary"
              phx-disable-with="Creating..."
              class="flex min-h-16 w-full items-center justify-center gap-3 rounded-2xl bg-amber-700 px-6 text-base font-semibold text-white shadow-lg shadow-amber-900/15 transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0 disabled:translate-y-0"
            >
              <.icon name="hero-language" class="size-5" /> Create Reading Log
            </.button>
          </div>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  defp save_reading_log(socket, params) do
    case Library.create_reading_log(
           params["name"],
           params["language_code"],
           empty_to_nil(params["word_goal"])
         ) do
      {:ok, reading_log} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{reading_log.name} is ready.")
         |> push_navigate(to: ~p"/")}

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't create this reading log. Check the details and try again."
         )
         |> assign(:form, to_form(params, as: :reading_log, action: :validate))}
    end
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

  defp empty_to_nil(value) when value in [nil, ""], do: nil
  defp empty_to_nil(value), do: value
end
