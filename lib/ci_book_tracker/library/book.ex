defmodule CiBookTracker.Library.Book do
  use Ash.Resource,
    domain: CiBookTracker.Library,
    data_layer: AshSqlite.DataLayer

  @editable_attributes [
    :title,
    :author,
    :page_count,
    :estimated_words,
    :difficulty_label,
    :status,
    :added_on,
    :started_on,
    :finished_on,
    :notes
  ]
  @cover_attributes [:cover_url, :cover_path, :cover_provider, :cover_id]

  sqlite do
    table "books"
    repo CiBookTracker.Repo

    references do
      reference :reading_log, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:reading_log_id | @editable_attributes]
      change CiBookTracker.Library.Book.Changes.DefaultReadingDates
    end

    create :create_with_cover do
      accept [:reading_log_id | @editable_attributes] ++ @cover_attributes
      validate CiBookTracker.Library.Book.Validations.CoverAttachment
      change CiBookTracker.Library.Book.Changes.DefaultReadingDates
      change CiBookTracker.Library.Book.Changes.ManageCoverFile
    end

    update :edit do
      primary? true
      accept @editable_attributes
    end

    update :edit_with_cover do
      accept @editable_attributes ++ @cover_attributes
      require_atomic? false
      validate CiBookTracker.Library.Book.Validations.CoverAttachment
      change CiBookTracker.Library.Book.Changes.ManageCoverFile
    end

    update :edit_without_cover do
      accept @editable_attributes
      require_atomic? false
      change set_attribute(:cover_url, nil)
      change set_attribute(:cover_path, nil)
      change set_attribute(:cover_provider, nil)
      change set_attribute(:cover_id, nil)
      change CiBookTracker.Library.Book.Changes.ManageCoverFile
    end

    update :attach_cover do
      accept @cover_attributes
      require_atomic? false
      validate CiBookTracker.Library.Book.Validations.CoverAttachment
      change CiBookTracker.Library.Book.Changes.ManageCoverFile
    end

    update :remove_cover do
      accept []
      require_atomic? false
      change set_attribute(:cover_url, nil)
      change set_attribute(:cover_path, nil)
      change set_attribute(:cover_provider, nil)
      change set_attribute(:cover_id, nil)
      change CiBookTracker.Library.Book.Changes.ManageCoverFile
    end

    update :start do
      accept []
      change set_attribute(:status, :in_progress)
      change CiBookTracker.Library.Book.Changes.SetStartedOnIfMissing
      change set_attribute(:finished_on, nil)
    end

    update :finish do
      accept []
      change set_attribute(:status, :finished)
      change CiBookTracker.Library.Book.Changes.CompleteReadingDates
    end

    update :abandon do
      accept []
      change set_attribute(:status, :abandoned)
      change CiBookTracker.Library.Book.Changes.SetStartedOnIfMissing
      change set_attribute(:finished_on, nil)
    end

    update :reopen do
      accept []
      change set_attribute(:status, :in_progress)
      change CiBookTracker.Library.Book.Changes.SetStartedOnIfMissing
    end

    destroy :destroy do
      require_atomic? false
      change CiBookTracker.Library.Book.Changes.RemoveCoverFile
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :reading_log_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :author, :string do
      public? true
    end

    attribute :page_count, :integer do
      public? true
      constraints min: 1
    end

    attribute :estimated_words, :integer do
      public? true
      constraints min: 1
    end

    attribute :cover_url, :string do
      public? true
    end

    attribute :cover_path, :string do
      public? true
    end

    attribute :cover_provider, :string do
      public? true
    end

    attribute :cover_id, :integer do
      public? true
      constraints min: 1
    end

    attribute :difficulty_label, :string do
      public? true
    end

    attribute :status, CiBookTracker.Library.BookStatus do
      allow_nil? false
      default :want_to_read
      public? true
    end

    attribute :added_on, :date do
      allow_nil? false
      default &Date.utc_today/0
      public? true
    end

    attribute :started_on, :date do
      public? true
    end

    attribute :finished_on, :date do
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :reading_log, CiBookTracker.Library.ReadingLog do
      source_attribute :reading_log_id
      define_attribute? false
      allow_nil? false
    end
  end
end
