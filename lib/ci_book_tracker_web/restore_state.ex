defmodule CiBookTrackerWeb.RestoreState do
  @moduledoc "The temporary state of a backup upload and restore."

  defstruct phase: :uploading, staged: nil, filename: nil, error: nil, result: nil

  def validating(filename), do: %__MODULE__{phase: :validating, filename: filename}

  def ready(staged, filename),
    do: %__MODULE__{phase: :ready, staged: staged, filename: filename}

  def complete(result), do: %__MODULE__{phase: :complete, result: result}

  def fail(state, message), do: %{state | error: message}
end
