defmodule CiBookTrackerWeb.BookCoverControllerTest do
  use CiBookTrackerWeb.ConnCase

  alias CiBookTracker.AppData

  test "serves a stored cover image", %{conn: conn} do
    AppData.ensure_cover_directory!()
    path = Path.join(AppData.cover_directory(), "served-cover.jpg")
    File.write!(path, "cover")

    conn = get(conn, ~p"/covers/served-cover.jpg")

    assert response(conn, 200) == "cover"
    assert get_resp_header(conn, "content-type") == ["image/jpeg; charset=utf-8"]
  end

  test "returns not found for missing cover images", %{conn: conn} do
    conn = get(conn, ~p"/covers/missing-cover.jpg")

    assert response(conn, 404) == "Not found"
  end
end
