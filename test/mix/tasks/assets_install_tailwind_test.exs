defmodule Mix.Tasks.Assets.InstallTailwindTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Assets.InstallTailwind

  @moduletag :tmp_dir

  setup %{tmp_dir: directory} do
    previous_path = Application.get_env(:tailwind, :path)
    previous_options = Req.default_options()
    path = Path.join(directory, "tailwind")
    Application.put_env(:tailwind, :path, path)
    Req.default_options(plug: {Req.Test, __MODULE__}, retry: false)

    on_exit(fn ->
      if previous_path,
        do: Application.put_env(:tailwind, :path, previous_path),
        else: Application.delete_env(:tailwind, :path)

      Req.default_options(previous_options)
    end)

    %{path: path}
  end

  test "installs the downloaded binary as an executable", %{path: path} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path =~ "/tailwindlabs/tailwindcss/releases/download/v"
      Plug.Conn.send_resp(conn, 200, <<0, 1, 2, 255>>)
    end)

    InstallTailwind.run([])

    assert File.read!(path) == <<0, 1, 2, 255>>
    assert Bitwise.band(File.stat!(path).mode, 0o777) == 0o755
    assert File.ls!(Path.dirname(path)) == ["tailwind"]
  end

  test "keeps a working binary when the server returns an error", %{path: path} do
    File.write!(path, "existing executable")

    Req.Test.expect(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 404, "not found")
    end)

    assert_raise Mix.Error, ~r/HTTP 404/, fn -> InstallTailwind.run([]) end
    assert File.read!(path) == "existing executable"
  end

  test "if-missing skips the network for an existing executable", %{path: path} do
    File.write!(path, "existing executable")
    InstallTailwind.run(["--if-missing"])
    assert File.read!(path) == "existing executable"
  end
end
