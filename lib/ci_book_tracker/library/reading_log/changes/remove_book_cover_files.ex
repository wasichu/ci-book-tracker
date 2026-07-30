defmodule CiBookTracker.Library.ReadingLog.Changes.RemoveBookCoverFiles do
  use Ash.Resource.Change

  alias CiBookTracker.Library
  alias CiBookTracker.Library.BookCover

  @impl true
  def change(changeset, _opts, _context) do
    reading_log_id = Ash.Changeset.get_data(changeset, :id)

    cover_paths =
      Library.list_books!(
        query: [filter: [reading_log_id: reading_log_id]],
        authorize?: false
      )
      |> Enum.map(& &1.cover_path)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      if match?({:ok, _reading_log}, result), do: Enum.each(cover_paths, &BookCover.remove/1)
      result
    end)
  end
end
