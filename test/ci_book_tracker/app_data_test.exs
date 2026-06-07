defmodule CiBookTracker.AppDataTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.AppData

  test "uses the Linux user data directory" do
    assert AppData.directory({:unix, :linux}, "/home/reader", %{}) ==
             "/home/reader/.local/share/reading_log"
  end

  test "uses the macOS application support directory" do
    assert AppData.directory({:unix, :darwin}, "/Users/reader", %{}) ==
             "/Users/reader/Library/Application Support/reading_log"
  end

  test "uses APPDATA on Windows" do
    assert AppData.directory({:win32, :nt}, "C:/Users/reader", %{
             "APPDATA" => "C:/Users/reader/AppData/Roaming"
           }) == "C:/Users/reader/AppData/Roaming/reading_log"
  end

  test "creates the database parent directory" do
    database_path =
      Path.join([
        System.tmp_dir!(),
        "ci_book_tracker_app_data_#{System.unique_integer([:positive])}",
        "nested",
        "reading_log.db"
      ])

    assert AppData.ensure_database_directory!(database_path) == database_path
    assert File.dir?(Path.dirname(database_path))
  end
end
