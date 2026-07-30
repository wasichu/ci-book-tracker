defmodule CiBookTracker.Library.Book.Changes.RemoveCoverFile do
  use Ash.Resource.Change

  alias CiBookTracker.Library.BookCover

  @impl true
  def change(changeset, _opts, _context) do
    cover_path = Ash.Changeset.get_data(changeset, :cover_path)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      if match?({:ok, _book}, result), do: BookCover.remove(cover_path)
      result
    end)
  end
end
