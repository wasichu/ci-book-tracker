defmodule CiBookTrackerWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias CiBookTrackerWeb.CoreComponents
  alias CiBookTrackerWeb.Layouts

  test "routine info flashes are not displayed by the app layout" do
    html =
      render_component(&Layouts.flash_group/1,
        flash: %{"info" => "Saved."}
      )

    refute html =~ "Saved."
    refute html =~ "flash-info"
    refute html =~ "AutoDismissFlash"
  end

  test "error flashes remain until manually dismissed" do
    html =
      render_component(&CoreComponents.flash/1,
        kind: :error,
        flash: %{"error" => "Try again."}
      )

    refute html =~ "AutoDismissFlash"
    assert html =~ "Try again."
    assert html =~ "workspace-notice"
    assert html =~ "Dismiss error"
    refute html =~ "fixed"
  end

  test "the layout still displays actionable errors" do
    html = render_component(&Layouts.flash_group/1, flash: %{"error" => "Backup exceeds 250 MB."})
    assert html =~ "Backup exceeds 250 MB."
    assert html =~ ~s(role="alert")
  end
end
