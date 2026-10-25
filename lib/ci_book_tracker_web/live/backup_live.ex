defmodule CiBookTrackerWeb.BackupLive do
  use CiBookTrackerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Backup and restore",
       backup_tab: "export",
       backup_directory: CiBookTracker.DatabaseRestore.backup_directory()
     )}
  end

  @impl true
  def handle_event("backup_tab", %{"tab" => tab}, socket) when tab in ~w(export restore) do
    {:noreply, assign(socket, :backup_tab, tab)}
  end
end
