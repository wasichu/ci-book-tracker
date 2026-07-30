defmodule CiBookTrackerWeb.ReadingLogSessionTest do
  use CiBookTracker.DataCase, async: true

  alias CiBookTracker.Library
  alias CiBookTrackerWeb.ReadingLogSession

  test "prefers an explicitly active reading log over auto-open" do
    active = Library.create_reading_log!("Active", "en", nil)
    automatic = Library.create_reading_log!("Automatic", "fr", nil)

    session = %{
      "active_reading_log_id" => active.id,
      "auto_open_reading_log_id" => automatic.id
    }

    assert ReadingLogSession.selected_id(session) == active.id
    assert {:ok, resolved} = ReadingLogSession.resolve(session)
    assert resolved.id == active.id
  end

  test "resolves auto-open logs and handles missing selections" do
    automatic = Library.create_reading_log!("Automatic", "fr", nil)

    assert ReadingLogSession.resolve_or_nil(%{"auto_open_reading_log_id" => automatic.id}).id ==
             automatic.id

    refute ReadingLogSession.selected?(%{})
    assert {:error, :not_found} = ReadingLogSession.resolve(%{})
    assert is_nil(ReadingLogSession.resolve_or_nil(%{"active_reading_log_id" => "missing"}))
  end
end
