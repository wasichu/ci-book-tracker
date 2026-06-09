defmodule CiBookTrackerWeb.WordEstimatorLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.Library.WordEstimator
  alias CiBookTrackerWeb.WordEstimatorComponents

  @empty_params %{
    "sample_text" => "",
    "sample_units" => "",
    "total_units" => "",
    "unit_type" => "pages"
  }

  @empty_result %{sample_words: 0, estimated_words: nil, message: nil}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Word estimator")
     |> assign(:form, to_form(@empty_params, as: :estimator))
     |> assign(:result, @empty_result)}
  end

  @impl true
  def handle_event("estimate", %{"estimator" => params}, socket) do
    {:noreply, assign_estimate(socket, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="word-estimator-page" class="space-y-7">
        <header>
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Reading tool
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Word Count Estimator
          </h1>
          <p class="mt-3 max-w-2xl text-base leading-7 text-slate-600">
            Estimate a book's total words from a representative sample. Nothing entered here is saved.
          </p>
        </header>

        <.form for={@form} id="word-estimator-form" phx-change="estimate">
          <WordEstimatorComponents.panel form={@form} result={@result} />
        </.form>

        <aside class="rounded-2xl border border-amber-200 bg-amber-50/70 p-5 text-sm leading-6 text-amber-950">
          <p class="font-semibold">For a better estimate</p>
          <p class="mt-1 text-amber-900/80">
            Use a normal section of prose rather than a title page, contents page, or unusually dialogue-heavy passage.
          </p>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  defp assign_estimate(socket, params) do
    result =
      if blank?(params) do
        @empty_result
      else
        case WordEstimator.evaluate(params) do
          {:ok, result} -> Map.put(result, :message, nil)
          {:error, result} -> Map.put(result, :estimated_words, nil)
        end
      end

    socket
    |> assign(:form, to_form(Map.merge(@empty_params, params), as: :estimator))
    |> assign(:result, result)
  end

  defp blank?(params) do
    Enum.all?(["sample_text", "sample_units", "total_units"], &(params[&1] in [nil, ""]))
  end
end
