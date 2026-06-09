defmodule CiBookTrackerWeb.WordEstimatorComponents do
  use CiBookTrackerWeb, :html

  alias CiBookTrackerWeb.BookFormat

  @unit_options [
    {"Pages", "pages"},
    {"Kindle locations", "kindle_locations"},
    {"Screens", "screens"},
    {"Chapters", "chapters"},
    {"Percent", "percent"}
  ]

  attr :form, :map, required: true
  attr :result, :map, required: true
  attr :apply_event, :string, default: nil
  attr :clear_event, :string, default: nil

  def panel(assigns) do
    assigns = assign(assigns, :unit_options, @unit_options)

    ~H"""
    <section
      id="word-estimate-helper"
      class="rounded-2xl border border-slate-200 bg-slate-50/70 p-4 sm:p-5"
    >
      <div class="flex items-start justify-between gap-4">
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

        <button
          :if={@clear_event}
          id="clear-word-estimate"
          type="button"
          phx-click={@clear_event}
          class="inline-flex min-h-10 shrink-0 items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 text-sm font-semibold text-slate-700 transition hover:border-slate-400 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-slate-400 focus:ring-offset-2"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Clear
        </button>
      </div>

      <div class="mt-5 space-y-5">
        <.input
          field={@form[:sample_text]}
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
            {BookFormat.number(@result.sample_words)}
          </strong>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <.input
            field={@form[:sample_units]}
            type="number"
            label="Sample unit count"
            placeholder="5"
            min="0.01"
            step="any"
            inputmode="decimal"
          />
          <.input
            field={@form[:total_units]}
            type="number"
            label="Total unit count"
            placeholder="180"
            min="0.01"
            step="any"
            inputmode="decimal"
          />
          <.input
            field={@form[:unit_type]}
            type="select"
            label="Unit type"
            options={@unit_options}
          />
        </div>

        <p
          :if={@result.message}
          id="word-estimate-error"
          class="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800"
        >
          {@result.message}
        </p>

        <div
          :if={@result.estimated_words}
          id="sample-estimated-words"
          class="rounded-xl border border-amber-200 bg-amber-50 p-4"
        >
          <p class="text-sm font-medium text-amber-900/70">Estimated total words</p>
          <p class="mt-1 text-2xl font-semibold tracking-tight text-amber-950">
            {BookFormat.number(@result.estimated_words)}
          </p>
        </div>

        <div :if={@apply_event}>
          <button
            id="apply-word-estimate"
            type="button"
            phx-click={@apply_event}
            disabled={is_nil(@result.estimated_words)}
            class="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 text-sm font-semibold text-white transition hover:bg-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 disabled:cursor-not-allowed disabled:bg-slate-300 sm:w-auto"
          >
            <.icon name="hero-arrow-up-tray" class="size-4" /> Apply Estimate
          </button>
        </div>
      </div>
    </section>
    """
  end
end
