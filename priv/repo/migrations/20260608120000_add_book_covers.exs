defmodule CiBookTracker.Repo.Migrations.AddBookCovers do
  use Ecto.Migration

  def change do
    alter table(:books) do
      add :cover_url, :text
      add :cover_provider, :text
      add :cover_id, :bigint
    end
  end
end
