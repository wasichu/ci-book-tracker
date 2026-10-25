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

  attr :workspace, :map, default: %{logs: [], log: nil, path: "/"}
  attr :canvas, :boolean, default: false

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div
      id="workspace"
      class="workspace"
      data-workspace
      phx-mounted={JS.ignore_attributes(["data-sidebar", "data-progress"])}
    >
      <div id="workspace-client" phx-hook="Workspace" phx-update="ignore" class="hidden"></div>
      <header class="workspace-header">
        <button
          type="button"
          class="workspace-icon-button"
          data-toggle-sidebar
          aria-label="Toggle navigation"
          aria-controls="workspace-sidebar"
          aria-expanded="true"
          phx-mounted={JS.ignore_attributes("aria-expanded")}
        >
          <.icon name="hero-bars-3" class="size-5" />
        </button>
        <.link id="workspace-home" navigate={~p"/?logs=all"} class="workspace-brand">
          <.icon name="hero-book-open" class="size-5" /> <span>CI Book Tracker</span>
        </.link>
        <div :if={@workspace.log} class="workspace-context">
          <span>{CiBookTrackerWeb.ReadingLogFormat.language_name(@workspace.log.language_code)}</span>
          <span aria-hidden="true">/</span><span>{@workspace.log.name}</span>
        </div>
        <button type="button" class="workspace-button workspace-quiet ml-auto" data-open-commands>
          <.icon name="hero-magnifying-glass" class="size-4" /> <span>Commands</span><kbd>⌘ K</kbd>
        </button>
      </header>
      <.flash_group flash={@flash} />
      <div class="workspace-body">
        <aside id="workspace-sidebar" class="workspace-sidebar" aria-label="Application navigation">
          <p class="workspace-eyebrow">Workspace</p>
          <.link
            id="workspace-library"
            navigate={if @workspace.log, do: ~p"/dashboard", else: ~p"/"}
            class={["workspace-nav", @workspace.path == "/dashboard" && "is-active"]}
          >
            <.icon name="hero-rectangle-stack" class="size-4" /> Library
          </.link>
          <.link
            :if={@workspace.log}
            id="workspace-progress"
            navigate={~p"/dashboard?view=progress"}
            class="workspace-nav"
          >
            <.icon name="hero-chart-bar" class="size-4" /> Progress
          </.link>
          <p class="workspace-eyebrow mt-7">Reading logs</p>
          <.link
            :for={log <- @workspace.logs}
            href={~p"/reading-logs/#{log.id}/open"}
            class={[
              "workspace-nav workspace-log",
              @workspace.log && @workspace.log.id == log.id && "is-active"
            ]}
            aria-current={if @workspace.log && @workspace.log.id == log.id, do: "page"}
          >
            <span class="workspace-dot"></span><span class="min-w-0 truncate">{log.name}</span><span class="workspace-log-language">{String.upcase(
              log.language_code
            )}</span>
          </.link>
          <.link navigate={~p"/reading-logs/new"} class="workspace-nav workspace-muted"><.icon
            name="hero-plus"
            class="size-4"
          /> New reading log</.link>
          <div class="workspace-sidebar-tools">
            <.link
              id="word-estimator-link"
              navigate={~p"/word-estimator"}
              class={["workspace-nav", @workspace.path == "/word-estimator" && "is-active"]}
            >
              <.icon name="hero-calculator" class="size-4" /> Word estimator
            </.link>
            <.link
              id="workspace-backup"
              navigate={~p"/backup"}
              class={[
                "workspace-nav",
                @workspace.path in ["/backup", "/settings/restore"] && "is-active"
              ]}
            >
              <.icon name="hero-archive-box" class="size-4" /> Backup and restore
            </.link>
            <.link
              id="settings-link"
              navigate={~p"/settings"}
              class={["workspace-nav", @workspace.path == "/settings" && "is-active"]}
            >
              <.icon name="hero-adjustments-horizontal" class="size-4" /> Settings
            </.link>
          </div>
          <span class="workspace-local"><span class="workspace-dot"></span>
          Your library, saved locally</span>
        </aside>
        <main id="workspace-main" class={["workspace-content", !@canvas && "workspace-document"]}>
          {render_slot(@inner_block)}
        </main>
      </div>
      <footer class="workspace-footer">
        <span class="workspace-dot"></span><span>Saved on this device</span>
        <span class="ml-auto">⌘ K Commands</span>
      </footer>
      <dialog
        id="workspace-commands"
        class="workspace-command-dialog"
        aria-labelledby="commands-title"
        phx-update="ignore"
      >
        <div class="workspace-dialog-heading">
          <h2 id="commands-title">Go anywhere</h2><button
            type="button"
            class="workspace-icon-button"
            data-close-commands
            aria-label="Close commands"
          ><.icon name="hero-x-mark" class="size-5" /></button>
        </div>
        <nav aria-label="Commands and keyboard shortcuts">
          <.link
            :if={@workspace.log}
            navigate={~p"/books/new"}
            class="workspace-command"
            data-command
            data-command-key="n"
          ><.icon
            name="hero-plus"
            class="size-5"
          /> Add a book <kbd>N</kbd></.link>
          <.link
            :if={@workspace.log}
            navigate={~p"/books/import"}
            class="workspace-command"
            data-command
            data-command-key="i"
          ><.icon name="hero-document-arrow-up" class="size-5" /> Import books from CSV <kbd>I</kbd></.link>
          <.link
            navigate={~p"/word-estimator"}
            class="workspace-command"
            data-command
            data-command-key="w"
          ><.icon
            name="hero-calculator"
            class="size-5"
          /> Word estimator <kbd>W</kbd></.link>
          <.link
            :if={@workspace.log}
            navigate={~p"/dashboard?view=progress"}
            class="workspace-command"
            data-command
            data-command-key="p"
          ><.icon name="hero-chart-bar" class="size-5" /> Reading progress <kbd>P</kbd></.link>
          <.link navigate={~p"/backup"} class="workspace-command" data-command data-command-key="b"><.icon
            name="hero-archive-box"
            class="size-5"
          /> Backup and restore <kbd>B</kbd></.link>
          <.link navigate={~p"/settings"} class="workspace-command" data-command data-command-key="s"><.icon
            name="hero-adjustments-horizontal"
            class="size-5"
          /> Settings <kbd>S</kbd></.link>
          <.link
            href={~p"/reading-log-session"}
            method="delete"
            class="workspace-command"
            data-command
            data-command-key="l"
          ><.icon
            name="hero-language"
            class="size-5"
          /> Manage reading logs <kbd>L</kbd></.link>
        </nav>
      </dialog>
    </div>
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
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Connection lost")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Reconnecting to your local library…")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("The app disconnected")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Reconnecting to your local library…")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
