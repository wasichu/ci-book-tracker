defmodule CiBookTracker.Library.Book.Validations.CoverAttachment do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    path = Ash.Changeset.get_attribute(changeset, :cover_path)
    url = Ash.Changeset.get_attribute(changeset, :cover_url)
    provider = Ash.Changeset.get_attribute(changeset, :cover_provider)
    cover_id = Ash.Changeset.get_attribute(changeset, :cover_id)

    cond do
      !present?(path) ->
        {:error, field: :cover_path, message: "must identify a stored cover"}

      provider == "local" && (present?(url) || !is_nil(cover_id)) ->
        {:error, field: :cover_provider, message: "does not accept a remote URL or ID"}

      provider == "local" ->
        :ok

      present?(url) ->
        :ok

      true ->
        {:error, field: :cover_url, message: "is required for a downloaded cover"}
    end
  end

  defp present?(value), do: is_binary(value) && String.trim(value) != ""
end
