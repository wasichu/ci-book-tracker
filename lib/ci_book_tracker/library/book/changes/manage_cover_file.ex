defmodule CiBookTracker.Library.Book.Changes.ManageCoverFile do
  use Ash.Resource.Change

  alias CiBookTracker.Library.BookCover

  @impl true
  def change(changeset, _opts, _context) do
    old_path = Ash.Changeset.get_data(changeset, :cover_path)
    new_path = Ash.Changeset.get_attribute(changeset, :cover_path)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      if old_path != new_path do
        case result do
          {:ok, _book} -> BookCover.remove(old_path)
          {:error, _error} -> BookCover.remove(new_path)
        end
      end

      result
    end)
  end
end
