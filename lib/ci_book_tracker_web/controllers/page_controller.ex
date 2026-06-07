defmodule CiBookTrackerWeb.PageController do
  use CiBookTrackerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
