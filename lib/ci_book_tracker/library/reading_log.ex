defmodule CiBookTracker.Library.ReadingLog do
  use Ash.Resource,
    domain: CiBookTracker.Library,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "reading_logs"
    repo CiBookTracker.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :language_code, :word_goal]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :language_code, :string do
      allow_nil? false
      default "es"
      public? true
    end

    attribute :word_goal, :integer do
      allow_nil? true
      public? true
      constraints min: 1
    end

    timestamps()
  end

  relationships do
    has_many :books, CiBookTracker.Library.Book
  end
end
