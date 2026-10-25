defmodule CiBookTrackerWeb.Workspace do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3, update: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogSession

  def on_mount(:default, _params, session, socket) do
    workspace = %{
      logs: Library.list_reading_logs!(query: [sort: [inserted_at: :asc]]),
      log: ReadingLogSession.resolve_or_nil(session),
      path: "/"
    }

    {:cont,
     socket
     |> assign(:workspace, workspace)
     |> attach_hook(:workspace_location, :handle_params, fn _params, uri, socket ->
       {:cont, update(socket, :workspace, &Map.put(&1, :path, URI.parse(uri).path))}
     end)}
  end
end
