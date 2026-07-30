defmodule CiBookTracker.AppData do
  @moduledoc false

  @app_directory "reading_log"
  @database_filename "reading_log.db"

  def directory do
    Application.get_env(:ci_book_tracker, :app_data_directory) ||
      directory(:os.type(), System.user_home!(), System.get_env())
  end

  def default_directory do
    directory(:os.type(), System.user_home!(), System.get_env())
  end

  def directory({:unix, :darwin}, home, _env) do
    Path.join([home, "Library", "Application Support", @app_directory])
  end

  def directory({:win32, _}, home, env) do
    env
    |> Map.get("APPDATA", Path.join([home, "AppData", "Roaming"]))
    |> Path.join(@app_directory)
  end

  def directory(_os_type, home, _env) do
    Path.join([home, ".local", "share", @app_directory])
  end

  def database_path do
    Path.join(directory(), @database_filename)
  end

  def cover_directory do
    Path.join(directory(), "covers")
  end

  def ensure_database_directory!(database_path \\ database_path()) do
    database_path
    |> Path.dirname()
    |> File.mkdir_p!()

    database_path
  end

  def ensure_cover_directory!(cover_directory \\ cover_directory()) do
    File.mkdir_p!(cover_directory)
    cover_directory
  end
end
