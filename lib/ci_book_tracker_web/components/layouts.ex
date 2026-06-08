defmodule CiBookTrackerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CiBookTrackerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-[radial-gradient(circle_at_top,_#fffbeb_0,_#f8fafc_42rem)]">
      <header class="border-b border-slate-200/80 bg-white/80 backdrop-blur">
        <div class="mx-auto flex max-w-3xl items-center justify-between gap-3 px-5 py-4">
          <a href={~p"/"} class="flex min-w-0 items-center gap-3 transition hover:text-amber-700">
            <span class="grid size-10 shrink-0 place-items-center rounded-2xl bg-amber-100 text-amber-800">
              <.icon name="hero-book-open" class="size-5" />
            </span>
            <span class="min-w-0">
              <span class="block truncate text-sm font-semibold tracking-tight">
                Comprehensible Input Reading Log
              </span>
              <span class="hidden text-xs text-slate-500 sm:block">
                Language learning, one book at a time
              </span>
            </span>
          </a>
          <.link
            id="settings-link"
            navigate={~p"/settings"}
            class="inline-flex min-h-11 shrink-0 items-center gap-2 rounded-xl px-3 text-sm font-semibold text-slate-600 transition hover:bg-amber-50 hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-600 focus:ring-offset-2"
          >
            <.icon name="hero-cog-6-tooth" class="size-4" />
            <span class="hidden sm:inline">Settings</span>
          </.link>
        </div>
      </header>

      <main class="mx-auto max-w-3xl px-5 py-8 sm:py-12">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
