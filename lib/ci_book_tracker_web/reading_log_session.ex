defmodule CiBookTrackerWeb.ReadingLogSession do
  @moduledoc false

  alias CiBookTracker.Library

  def selected_id(session) do
    session["active_reading_log_id"] || session["auto_open_reading_log_id"]
  end

  def selected?(session), do: !is_nil(selected_id(session))

  def resolve(session) do
    case selected_id(session) do
      nil -> {:error, :not_found}
      id -> Library.get_reading_log(id)
    end
  end

  def resolve_or_nil(session) do
    case resolve(session) do
      {:ok, reading_log} -> reading_log
      {:error, _error} -> nil
    end
  end
end
