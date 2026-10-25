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

  test "rejects an export whose database and covers together exceed the restore limit" do
    directory = temporary_directory()
    File.mkdir_p!(Path.join(directory, "covers"))
    on_exit(fn -> File.rm_rf(directory) end)
    database = Path.join(directory, "source.db")
    archive = Path.join(directory, "backup.zip")
    write_sparse_file(database, BackupArchive.max_bytes())
    File.write!(Path.join(directory, "covers/cover.jpg"), "cover")

    assert {:error, :backup_too_large} =
             BackupArchive.create(archive, database, Path.join(directory, "covers"))

    refute File.exists?(archive)
    assert File.stat!(database).size == BackupArchive.max_bytes()
  end

  test "rejects oversized ZIP and legacy database files before processing them" do
    directory = temporary_directory()
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf(directory) end)
    path = Path.join(directory, "oversized.backup")
    write_sparse_file(path, BackupArchive.max_bytes() + 1)

    assert {:error, :backup_too_large} =
             BackupArchive.stage(path, fn _ -> flunk("must reject before staging") end)

    assert {:error, :backup_too_large} = CiBookTracker.DatabaseRestore.stage(path)
  end

  test "rejects small ZIP files with oversized expanded contents before extraction" do
    directory = temporary_directory()
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf(directory) end)
    path = Path.join(directory, "expanded.zip")
    {:ok, _} = :zip.create(String.to_charlist(path), [{~c"reading_log.db", "database"}])

    # Change the central directory's expanded size without allocating a large fixture.
    zip = File.read!(path)
    {central_directory, _} = :binary.match(zip, <<0x50, 0x4B, 0x01, 0x02>>)
    size_offset = central_directory + 24
    <<prefix::binary-size(^size_offset), _old_size::little-32, suffix::binary>> = zip

    File.write!(
      path,
      <<prefix::binary, BackupArchive.max_bytes() + 1::little-32, suffix::binary>>
    )

    assert {:error, :backup_too_large} =
             BackupArchive.stage(path, fn _ -> flunk("must reject before extraction") end)
  end

  defp write_sparse_file(path, size) do
    File.open!(path, [:write, :binary], fn file ->
      {:ok, _} = :file.position(file, size - 1)
      IO.binwrite(file, <<0>>)
    end)
  end

  defp temporary_directory do
    Path.join(
      System.tmp_dir!(),
      "ci_book_tracker_archive_#{System.unique_integer([:positive])}"
    )
  end
end
