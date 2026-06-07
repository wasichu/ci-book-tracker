defmodule CiBookTracker.Library.Book.Changes.SetStartedOnIfMissing do
  use Ash.Resource.Change

  import Ash.Expr

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_attribute(changeset, :started_on) do
      changeset
    else
      Ash.Changeset.change_attribute(changeset, :started_on, Date.utc_today())
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    today = Date.utc_today()

    {:atomic, %{started_on: expr(if is_nil(started_on), do: ^today, else: started_on)}}
  end
end
