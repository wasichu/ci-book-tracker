defmodule CiBookTracker.Settings.ProviderSetting do
  use Ash.Resource,
    domain: CiBookTracker.Settings,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "provider_settings"
    repo CiBookTracker.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:provider, :enabled, :credential]
    end

    update :update do
      primary? true
      accept [:enabled, :credential]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :provider, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:google_books, :hardcover]
    end

    attribute :enabled, :boolean do
      allow_nil? false
      default true
      public? true
    end

    attribute :credential, :string do
      public? true
      sensitive? true
    end

    timestamps()
  end

  identities do
    identity :unique_provider, [:provider]
  end
end
