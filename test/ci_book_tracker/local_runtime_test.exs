defmodule CiBookTracker.LocalRuntimeTest do
  use ExUnit.Case, async: false

  alias CiBookTracker.LocalRuntime

  @moduletag :tmp_dir

  setup do
    previous = System.get_env("SECRET_KEY_BASE")
    System.delete_env("SECRET_KEY_BASE")

    on_exit(fn ->
      if previous,
        do: System.put_env("SECRET_KEY_BASE", previous),
        else: System.delete_env("SECRET_KEY_BASE")
    end)
  end

  test "generates a private, stable secret on first start", %{tmp_dir: directory} do
    secret = LocalRuntime.secret_key_base(directory)
    path = Path.join(directory, "secret_key_base")

    assert byte_size(secret) >= 64
    assert File.read!(path) == secret
    assert LocalRuntime.secret_key_base(directory) == secret
    assert Bitwise.band(File.stat!(path).mode, 0o777) == 0o600
  end

  test "concurrent first starts use the same complete secret", %{tmp_dir: directory} do
    secrets =
      1..10
      |> Task.async_stream(fn _ -> LocalRuntime.secret_key_base(directory) end)
      |> Enum.map(fn {:ok, secret} -> secret end)
      |> Enum.uniq()

    assert [secret] = secrets
    assert byte_size(secret) >= 64
    assert File.ls!(directory) == ["secret_key_base"]
  end

  test "environment override does not write a file", %{tmp_dir: directory} do
    secret = String.duplicate("a", 64)
    System.put_env("SECRET_KEY_BASE", secret)

    assert LocalRuntime.secret_key_base(directory) == secret
    refute File.exists?(Path.join(directory, "secret_key_base"))
  end

  test "invalid saved secret fails without replacing it", %{tmp_dir: directory} do
    path = Path.join(directory, "secret_key_base")
    File.write!(path, "broken")

    assert_raise RuntimeError, ~r/must contain at least 64 bytes/, fn ->
      LocalRuntime.secret_key_base(directory)
    end

    assert File.read!(path) == "broken"
  end
end
