defmodule CiBookTrackerWeb.WordEstimatorLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTrackerWeb.WordEstimatorComponents
  alias CiBookTrackerWeb.WordEstimatorForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Word estimator")
     |> assign_estimate(%{})}
  end

  @impl true
  def handle_event("estimate", %{"estimator" => params}, socket) do
    {:noreply, assign_estimate(socket, params)}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign_estimate(socket, %{})}
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
          <WordEstimatorComponents.panel form={@form} result={@result} clear_event="clear" />
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
    {form, result} = WordEstimatorForm.build(params)

    socket
    |> assign(:form, form)
    |> assign(:result, result)
  end
end
