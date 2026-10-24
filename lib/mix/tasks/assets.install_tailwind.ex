defmodule Mix.Tasks.Assets.InstallTailwind do
  @moduledoc """
  Installs the configured Tailwind binary using Req.

  Use `--if-missing` to keep an already installed binary. This avoids the
  built-in installer's HTTP response header limit on GitHub release downloads.
  """

  use Mix.Task

  @shortdoc "Installs the configured Tailwind binary using Req"

  @impl true
  def run(args) do
    Mix.Task.run("loadpaths")
    {options, []} = OptionParser.parse!(args, strict: [if_missing: :boolean])
    version = Tailwind.configured_version(:ci_book_tracker)
    path = Tailwind.bin_path(version)

    unless options[:if_missing] && File.exists?(path) do
      {:ok, _} = Application.ensure_all_started(:req)
      target = Tailwind.configured_target(:ci_book_tracker)

      url =
        "https://github.com/tailwindlabs/tailwindcss/releases/download/v#{version}/tailwindcss-#{target}"

      Mix.shell().info("Downloading Tailwind #{version} for #{target}")

      response = Req.get!(url, decode_body: false, receive_timeout: 120_000)

      if response.status != 200 do
        Mix.raise("Tailwind download failed with HTTP #{response.status}")
      end

      temporary = path <> ".download-#{System.unique_integer([:positive])}"
      File.mkdir_p!(Path.dirname(path))

      try do
        File.write!(temporary, response.body)
        File.chmod!(temporary, 0o755)
        File.rename!(temporary, path)
      after
        File.rm(temporary)
      end
    end
  end
end
