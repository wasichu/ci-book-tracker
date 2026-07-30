defmodule CiBookTrackerWeb.BookCoverController do
  use CiBookTrackerWeb, :controller

  alias CiBookTracker.Library.BookCover

  def show(conn, %{"filename" => filename}) do
    filename = Path.basename(filename)
    path = BookCover.local_path(filename)

    if File.regular?(path) do
      conn
      |> put_resp_content_type(BookCover.content_type(filename))
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Not found")
    end
  end
end
