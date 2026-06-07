defmodule CiBookTracker.Library.Book.Changes.DefaultReadingDates do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    status = Ash.Changeset.get_attribute(changeset, :status)
    started_on = Ash.Changeset.get_attribute(changeset, :started_on)
    finished_on = Ash.Changeset.get_attribute(changeset, :finished_on)
    today = Date.utc_today()

    case status do
      :in_progress ->
        put_if_missing(changeset, :started_on, started_on, today)

      :finished ->
        default_finished_on = finished_on || today

        changeset
        |> put_if_missing(:finished_on, finished_on, today)
        |> put_if_missing(:started_on, started_on, default_finished_on)

      _other ->
        changeset
    end
  end

  defp put_if_missing(changeset, _attribute, value, _default) when not is_nil(value),
    do: changeset

  defp put_if_missing(changeset, attribute, nil, default),
    do: Ash.Changeset.change_attribute(changeset, attribute, default)
end
