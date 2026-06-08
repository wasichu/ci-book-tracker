defmodule CiBookTrackerWeb.SettingsLive do
  use CiBookTrackerWeb, :live_view

  alias CiBookTracker.DatabaseBackup
  alias CiBookTracker.Settings.MetadataProviders

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign_database()
     |> assign_application()
     |> assign_provider_forms()}
  end

  @impl true
  def handle_event("save_provider", %{"provider" => params}, socket) do
    provider = provider(params["name"])
    enabled = params["enabled"] == "true"
    credential = params["credential"] || ""

    enabled =
      if provider == :hardcover do
        enabled && credential_available?(credential, MetadataProviders.credential(:hardcover))
      else
        enabled
      end

    case MetadataProviders.save(provider, enabled, credential) do
      {:ok, _setting} ->
        message =
          if provider == :hardcover && params["enabled"] == "true" && !enabled do
            "Hardcover remains disabled until an API token is provided."
          else
            "#{provider_label(provider)} settings saved."
          end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign_provider_forms()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "The provider settings could not be saved.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section id="settings-page" class="space-y-8">
        <header>
          <.link
            navigate={~p"/"}
            class="inline-flex min-h-11 items-center gap-2 rounded-xl pr-3 text-sm font-semibold text-slate-600 transition hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to reading logs
          </.link>
          <p class="mt-5 text-xs font-semibold uppercase tracking-[0.18em] text-amber-700">
            Configuration
          </p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">
            Settings
          </h1>
          <p class="mt-3 max-w-xl text-base leading-7 text-slate-600">
            Manage local storage and optional book metadata services.
          </p>
        </header>

        <.settings_section
          id="database-settings"
          icon="hero-circle-stack"
          title="Database"
          intro="All reading logs, books, and settings are stored locally in a SQLite database."
        >
          <dl class="divide-y divide-slate-100 text-sm">
            <.detail_row term="File location" value={@database.path} value_class="break-all" />
            <.detail_row term="File size" value={@database.size} />
            <.detail_row :if={@database.modified} term="Last modified" value={@database.modified} />
          </dl>
          <.link
            id="settings-export-database"
            href={~p"/backup/database"}
            class="mt-6 flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl bg-slate-950 px-5 font-semibold text-white transition hover:-translate-y-0.5 hover:bg-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 active:translate-y-0"
          >
            <.icon name="hero-arrow-down-tray" class="size-5" /> Export Database
          </.link>
          <div class="mt-6 border-t border-rose-100 pt-6">
            <p class="text-sm leading-6 text-slate-600">
              Restore replaces every reading log, book, and saved provider setting.
            </p>
            <.link
              id="settings-restore-database"
              navigate={~p"/settings/restore"}
              class="mt-4 flex min-h-14 w-full items-center justify-center gap-2 rounded-2xl border border-rose-300 bg-rose-50 px-5 font-semibold text-rose-800 transition hover:-translate-y-0.5 hover:bg-rose-100 focus:outline-none focus:ring-2 focus:ring-rose-600 focus:ring-offset-2 active:translate-y-0"
            >
              <.icon name="hero-arrow-path" class="size-5" /> Restore Database
            </.link>
          </div>
        </.settings_section>

        <.settings_section
          id="metadata-provider-settings"
          icon="hero-magnifying-glass"
          title="Metadata Providers"
          intro="Choose which services can be used when searching for book details."
        >
          <div class="space-y-6">
            <article
              id="open-library-settings"
              class="rounded-2xl bg-emerald-50 p-4 ring-1 ring-emerald-100"
            >
              <div class="flex items-center justify-between gap-4">
                <h3 class="font-semibold text-slate-950">Open Library</h3>
                <span class="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-800">
                  Enabled
                </span>
              </div>
              <p class="mt-2 text-sm leading-6 text-slate-600">
                Open Library is available without an API key.
              </p>
            </article>

            <.provider_form
              id="google-books-settings"
              title="Google Books"
              description="Works without a key, though a key can improve quota availability."
              form={@google_books_form}
              credential_label="Optional API key"
              credential_placeholder="Leave empty to search without a key"
            />

            <.provider_form
              id="hardcover-settings"
              title="Hardcover"
              description="Requires an API token. Hardcover stays unavailable until a token is configured."
              form={@hardcover_form}
              credential_label="API token"
              credential_placeholder="Paste your Hardcover API token"
            />
          </div>
        </.settings_section>

        <.settings_section
          id="application-settings"
          icon="hero-information-circle"
          title="Application"
          intro="Runtime information for this installation."
        >
          <dl class="divide-y divide-slate-100 text-sm">
            <.detail_row term="Version" value={@application.version} />
          </dl>
        </.settings_section>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :intro, :string, required: true
  slot :inner_block, required: true

  defp settings_section(assigns) do
    ~H"""
    <section
      id={@id}
      class="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm shadow-slate-200/60 sm:p-8"
    >
      <div class="flex items-start gap-4">
        <span class="grid size-12 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
          <.icon name={@icon} class="size-6" />
        </span>
        <div>
          <h2 class="text-xl font-semibold tracking-tight text-slate-950">{@title}</h2>
          <p class="mt-2 text-sm leading-6 text-slate-600">{@intro}</p>
        </div>
      </div>
      <div class="mt-6">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :credential_label, :string, required: true
  attr :credential_placeholder, :string, required: true

  defp provider_form(assigns) do
    ~H"""
    <article id={@id} class="rounded-2xl border border-slate-200 p-4 sm:p-5">
      <h3 class="font-semibold text-slate-950">{@title}</h3>
      <p class="mt-1 text-sm leading-6 text-slate-600">{@description}</p>
      <.form for={@form} phx-submit="save_provider" class="mt-4 space-y-4">
        <input type="hidden" name={@form[:name].name} value={@form[:name].value} />
        <.input
          id={"#{@id}-enabled"}
          field={@form[:enabled]}
          type="checkbox"
          label="Enabled"
        />
        <.input
          id={"#{@id}-credential"}
          field={@form[:credential]}
          type="password"
          label={@credential_label}
          placeholder={@credential_placeholder}
          autocomplete="off"
        />
        <.button
          type="submit"
          phx-disable-with="Saving..."
          class="flex min-h-12 w-full items-center justify-center rounded-xl bg-amber-100 px-5 font-semibold text-amber-950 transition hover:bg-amber-200 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2 sm:w-auto"
        >
          Save {@title}
        </.button>
      </.form>
    </article>
    """
  end

  attr :term, :string, required: true
  attr :value, :string, required: true
  attr :value_class, :string, default: nil

  defp detail_row(assigns) do
    ~H"""
    <div class="grid gap-1 py-3 sm:grid-cols-[9rem_1fr] sm:gap-4">
      <dt class="font-medium text-slate-500">{@term}</dt>
      <dd class={["font-semibold text-slate-900", @value_class]}>{@value}</dd>
    </div>
    """
  end

  defp assign_database(socket) do
    path = DatabaseBackup.database_path()

    database =
      case File.stat(path) do
        {:ok, stat} ->
          %{path: path, size: format_bytes(stat.size), modified: format_modified(stat.mtime)}

        {:error, _reason} ->
          %{path: path, size: "Not available", modified: nil}
      end

    assign(socket, :database, database)
  end

  defp assign_application(socket) do
    application = %{
      version: :ci_book_tracker |> Application.spec(:vsn) |> to_string()
    }

    assign(socket, :application, application)
  end

  defp assign_provider_forms(socket) do
    providers = MetadataProviders.all()

    socket
    |> assign(:google_books_form, provider_form(:google_books, providers.google_books))
    |> assign(:hardcover_form, provider_form(:hardcover, providers.hardcover))
  end

  defp provider_form(provider, config) do
    to_form(
      %{
        "name" => Atom.to_string(provider),
        "enabled" => config.enabled,
        "credential" => config.credential || ""
      },
      as: :provider
    )
  end

  defp provider("hardcover"), do: :hardcover
  defp provider(_provider), do: :google_books

  defp provider_label(:hardcover), do: "Hardcover"
  defp provider_label(:google_books), do: "Google Books"

  defp credential_available?(submitted, existing) do
    String.trim(submitted) != "" || (is_binary(existing) && existing != "")
  end

  defp format_bytes(bytes) when bytes < 1_024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_modified(datetime) do
    datetime
    |> NaiveDateTime.from_erl!()
    |> Calendar.strftime("%b %-d, %Y at %-I:%M %p")
  end
end
