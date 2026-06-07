defmodule CiBookTracker.Repo.Migrations.RepairBooksReadingLogForeignKey do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    rebuild_books_table("reading_logs")
  end

  def down do
    rebuild_books_table("reading_logs")
  end

  defp rebuild_books_table(reading_logs_table) do
    execute "PRAGMA foreign_keys = OFF"
    execute "ALTER TABLE books RENAME TO books_old"

    execute """
    CREATE TABLE books (
      updated_at TEXT NOT NULL,
      inserted_at TEXT NOT NULL,
      notes TEXT,
      finished_on TEXT,
      started_on TEXT,
      added_on TEXT NOT NULL,
      status TEXT NOT NULL,
      difficulty_label TEXT,
      estimated_words INTEGER,
      page_count INTEGER,
      author TEXT,
      title TEXT NOT NULL,
      reading_log_id TEXT NOT NULL
        CONSTRAINT books_reading_log_id_fkey
        REFERENCES #{reading_logs_table}(id)
        ON DELETE CASCADE,
      id TEXT NOT NULL PRIMARY KEY
    )
    """

    execute """
    INSERT INTO books (
      updated_at,
      inserted_at,
      notes,
      finished_on,
      started_on,
      added_on,
      status,
      difficulty_label,
      estimated_words,
      page_count,
      author,
      title,
      reading_log_id,
      id
    )
    SELECT
      updated_at,
      inserted_at,
      notes,
      finished_on,
      started_on,
      added_on,
      status,
      difficulty_label,
      estimated_words,
      page_count,
      author,
      title,
      reading_log_id,
      id
    FROM books_old
    """

    execute "DROP TABLE books_old"
    execute "PRAGMA foreign_keys = ON"
  end
end
