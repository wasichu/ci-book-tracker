defmodule CiBookTrackerWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias CiBookTrackerWeb.CoreComponents

  test "info flashes opt into automatic dismissal" do
    html =
      render_component(&CoreComponents.flash/1,
        kind: :info,
        flash: %{"info" => "Saved."}
      )

    assert html =~ ~s(phx-hook="AutoDismissFlash")
    assert html =~ "transition-opacity duration-200"
  end

  test "error flashes remain until manually dismissed" do
    html =
      render_component(&CoreComponents.flash/1,
        kind: :error,
        flash: %{"error" => "Try again."}
      )

    refute html =~ "AutoDismissFlash"
    assert html =~ "Try again."
  end
end
