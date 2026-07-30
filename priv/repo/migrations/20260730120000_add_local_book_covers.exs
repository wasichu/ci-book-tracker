defmodule CiBookTracker.Repo.Migrations.AddLocalBookCovers do
  use Ecto.Migration

  def change do
    alter table(:books) do
      add :cover_path, :text
    end
  end
end
