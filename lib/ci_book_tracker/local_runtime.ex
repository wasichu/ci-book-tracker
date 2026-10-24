defmodule CiBookTracker.LocalRuntime do
  @moduledoc false

  # Called by runtime.exs before the application (and its supervision tree) starts.
  def secret_key_base(directory) do
    case System.get_env("SECRET_KEY_BASE") do
      nil -> persisted_secret(directory)
      secret -> validate_secret!(secret)
    end
  end

  defp persisted_secret(directory) do
    path = Path.join(directory, "secret_key_base")

    case File.read(path) do
      {:ok, secret} ->
        validate_secret!(secret)

      {:error, :enoent} ->
        File.mkdir_p!(directory)
        create_secret(path)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read", path: path
    end
  end

  defp create_secret(path) do
    secret = :crypto.strong_rand_bytes(64) |> Base.encode64()
    temporary = path <> "." <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

    try do
      File.open!(temporary, [:write, :exclusive, :binary], fn file ->
        File.chmod!(temporary, 0o600)
        :ok = IO.binwrite(file, secret)
      end)

      # Publish only a complete file, without overwriting another process's key.
      case File.ln(temporary, path) do
        :ok -> secret
        {:error, :eexist} -> path |> File.read!() |> validate_secret!()
        {:error, reason} -> raise File.Error, reason: reason, action: "link", path: path
      end
    after
      File.rm(temporary)
    end
  end

  defp validate_secret!(secret) when byte_size(secret) >= 64, do: secret

  defp validate_secret!(_secret) do
    raise "SECRET_KEY_BASE (or the saved secret_key_base file) must contain at least 64 bytes"
  end
end
