defmodule CiBookTracker.BackupArchiveTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.BackupArchive

  test "packs and safely stages the portable backup layout" do
    directory = temporary_directory()
    database_path = Path.join(directory, "source.db")
    cover_directory = Path.join(directory, "covers")
    archive_path = Path.join(directory, "backup.zip")
    File.mkdir_p!(cover_directory)
    File.write!(database_path, "database")
    File.write!(Path.join(cover_directory, "cover.jpg"), "cover")
    on_exit(fn -> File.rm_rf(directory) end)

    assert {:ok, ^archive_path} =
             BackupArchive.create(archive_path, database_path, cover_directory)

    validate_database = fn staged_path ->
      if File.read!(staged_path) == "database", do: :ok, else: {:error, :invalid_database}
    end

    assert {:ok, staged} = BackupArchive.stage(archive_path, validate_database)

    try do
      assert File.read!(staged.database_path) == "database"
      assert File.read!(Path.join(staged.cover_directory, "cover.jpg")) == "cover"
    after
      BackupArchive.cleanup(staged)
    end
  end

  test "rejects entries outside the portable backup layout" do
    directory = temporary_directory()
    archive_path = Path.join(directory, "unsafe.zip")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf(directory) end)

    assert {:ok, _path} =
             :zip.create(String.to_charlist(archive_path), [
               {~c"reading_log.db", "database"},
               {~c"../outside.jpg", "cover"}
             ])

    assert {:error, :unsafe_archive} = BackupArchive.stage(archive_path, fn _path -> :ok end)
  end

  defp temporary_directory do
    Path.join(
      System.tmp_dir!(),
      "ci_book_tracker_archive_#{System.unique_integer([:positive])}"
    )
  end
end
