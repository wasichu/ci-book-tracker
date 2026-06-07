defmodule CiBookTracker.Library.Book.Changes.CompleteReadingDates do
  use Ash.Resource.Change

  import Ash.Expr

  @impl true
  def change(changeset, _opts, _context) do
    finished_on = Ash.Changeset.get_attribute(changeset, :finished_on) || Date.utc_today()

    changeset
    |> Ash.Changeset.change_attribute(:finished_on, finished_on)
    |> Ash.Changeset.change_attribute(
      :started_on,
      Ash.Changeset.get_attribute(changeset, :started_on) || finished_on
    )
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    today = Date.utc_today()

    {:atomic,
     %{
       finished_on: expr(if is_nil(finished_on), do: ^today, else: finished_on),
       started_on:
         expr(
           if is_nil(started_on),
             do: if(is_nil(finished_on), do: ^today, else: finished_on),
             else: started_on
         )
     }}
  end
end
