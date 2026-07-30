defmodule CiBookTracker.Library.BookCover do
  @moduledoc """
  Stores book cover images in the local application data directory.
  """

  alias CiBookTracker.AppData
  alias CiBookTracker.Library

  @allowed_extensions ~w(.jpg .jpeg .png .webp .gif)
  @content_type_extensions %{
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "image/webp" => ".webp",
    "image/gif" => ".gif"
  }
  @max_bytes 8 * 1024 * 1024

  @type stored_cover :: %{cover_path: String.t(), cover_url: String.t() | nil}

  @spec store_upload(String.t(), String.t()) :: {:ok, stored_cover()} | {:error, atom()}
  def store_upload(source_path, client_name) do
    with {:ok, extension} <- extension_from_filename(client_name),
         {:ok, stat} <- File.stat(source_path),
         :ok <- validate_size(stat.size),
         {:ok, filename} <- copy_cover(source_path, extension) do
      {:ok, %{cover_path: filename, cover_url: nil}}
    end
  end

  @spec store_url(String.t()) :: {:ok, stored_cover()} | {:error, atom()}
  def store_url(url) when is_binary(url) do
    url = String.trim(url)

    with {:ok, uri} <- validate_url(url),
         {:ok, response} <- request(uri),
         :ok <- validate_response(response),
         {:ok, extension} <- extension_from_response(response, uri),
         :ok <- validate_size(byte_size(response.body)),
         {:ok, filename} <- write_cover(response.body, extension) do
      {:ok, %{cover_path: filename, cover_url: url}}
    end
  rescue
    _exception -> {:error, :download_failed}
  end

  def store_url(_url), do: {:error, :invalid_url}

  @spec local_path(String.t()) :: String.t()
  def local_path(filename) do
    AppData.cover_directory()
    |> Path.join(Path.basename(filename))
  end

  @spec public_path(String.t() | nil) :: String.t() | nil
  def public_path(nil), do: nil
  def public_path(""), do: nil

  def public_path(filename) do
    "/covers/#{Path.basename(filename)}"
  end

  @spec content_type(String.t()) :: String.t()
  def content_type(filename) do
    case String.downcase(Path.extname(filename)) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      ".gif" -> "image/gif"
      _other -> "application/octet-stream"
    end
  end

  @spec backfill_remote_covers() :: %{
          downloaded: non_neg_integer(),
          skipped: non_neg_integer(),
          failed: non_neg_integer()
        }
  def backfill_remote_covers do
    Library.list_books!()
    |> Enum.reduce(%{downloaded: 0, skipped: 0, failed: 0}, fn book, totals ->
      cond do
        present?(book.cover_path) || !present?(book.cover_url) ->
          Map.update!(totals, :skipped, &(&1 + 1))

        true ->
          case store_url(book.cover_url) do
            {:ok, %{cover_path: cover_path}} ->
              case Library.edit_book(book, %{cover_path: cover_path}) do
                {:ok, _book} -> Map.update!(totals, :downloaded, &(&1 + 1))
                {:error, _error} -> Map.update!(totals, :failed, &(&1 + 1))
              end

            {:error, _reason} ->
              Map.update!(totals, :failed, &(&1 + 1))
          end
      end
    end)
  end

  defp validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) ->
        {:ok, uri}

      _invalid ->
        {:error, :invalid_url}
    end
  end

  defp request(uri) do
    options =
      config()
      |> Keyword.get(:request_options, [])
      |> Keyword.merge(url: URI.to_string(uri), retry: false, receive_timeout: 15_000)

    case Req.get(options) do
      {:ok, response} -> {:ok, response}
      {:error, %{reason: :timeout}} -> {:error, :timeout}
      {:error, _error} -> {:error, :download_failed}
    end
  end

  defp validate_response(%{status: status}) when status in 200..299, do: :ok
  defp validate_response(_response), do: {:error, :download_failed}

  defp extension_from_response(response, uri) do
    content_type =
      response
      |> Req.Response.get_header("content-type")
      |> List.first()
      |> content_type_without_params()

    cond do
      extension = @content_type_extensions[content_type] ->
        {:ok, extension}

      Path.extname(uri.path || "") |> valid_extension?() ->
        {:ok, normalize_extension(Path.extname(uri.path))}

      true ->
        {:error, :unsupported_type}
    end
  end

  defp extension_from_filename(filename) do
    extension = filename |> Path.extname() |> normalize_extension()

    if valid_extension?(extension),
      do: {:ok, extension},
      else: {:error, :unsupported_type}
  end

  defp content_type_without_params(nil), do: nil

  defp content_type_without_params(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp validate_size(size) when is_integer(size) and size > 0 and size <= @max_bytes, do: :ok
  defp validate_size(size) when is_integer(size) and size > @max_bytes, do: {:error, :too_large}
  defp validate_size(_size), do: {:error, :empty}

  defp copy_cover(source_path, extension) do
    filename = filename(extension)
    destination = destination(filename)

    case File.cp(source_path, destination) do
      :ok -> {:ok, filename}
      {:error, _reason} -> {:error, :storage_failed}
    end
  end

  defp write_cover(contents, extension) do
    filename = filename(extension)
    destination = destination(filename)

    case File.write(destination, contents) do
      :ok -> {:ok, filename}
      {:error, _reason} -> {:error, :storage_failed}
    end
  end

  defp destination(filename) do
    AppData.ensure_cover_directory!()
    |> Path.join(filename)
  end

  defp filename(extension),
    do: "#{System.unique_integer([:positive])}-#{Ecto.UUID.generate()}#{extension}"

  defp normalize_extension(extension), do: String.downcase(extension || "")
  defp valid_extension?(extension), do: extension in @allowed_extensions
  defp present?(value), do: is_binary(value) && String.trim(value) != ""
  defp config, do: Application.get_env(:ci_book_tracker, __MODULE__, [])
end
