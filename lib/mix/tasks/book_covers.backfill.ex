defmodule Mix.Tasks.BookCovers.Backfill do
  @moduledoc """
  Downloads remote book covers that were saved before local cover storage existed.
  """

  use Mix.Task

  alias CiBookTracker.Library.BookCover

  @shortdoc "Downloads existing remote book covers into local app storage"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    %{downloaded: downloaded, skipped: skipped, failed: failed} =
      BookCover.backfill_remote_covers()

    Mix.shell().info("""
    Book cover backfill complete.
    Downloaded: #{downloaded}
    Skipped: #{skipped}
    Failed: #{failed}
    """)
  end
end
