defmodule CiBookTracker.Library.BookMetadata.Normalization do
  @moduledoc false

  @language_codes %{
    "deu" => "de",
    "eng" => "en",
    "fra" => "fr",
    "fre" => "fr",
    "ger" => "de",
    "ita" => "it",
    "por" => "pt",
    "spa" => "es"
  }

  def isbn(value) when is_binary(value) do
    normalized =
      value
      |> String.replace(~r/[\s-]/, "")
      |> String.upcase()

    if Regex.match?(~r/^(?:\d{13}|\d{9}[\dX])$/, normalized), do: normalized
  end

  def isbn(_value), do: nil

  def language_code(value) when is_binary(value) do
    normalized =
      value
      |> String.downcase()
      |> String.split("-")
      |> List.first()

    Map.get(@language_codes, normalized, normalized)
  end

  def language_code(_value), do: nil

  def positive_integer(value) when is_integer(value) and value > 0, do: value
  def positive_integer(_value), do: nil

  def positive_integer_string(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _invalid -> nil
    end
  end

  def positive_integer_string(value), do: positive_integer(value)

  def secure_url("http://" <> rest), do: "https://" <> rest
  def secure_url(value) when is_binary(value), do: value
  def secure_url(_value), do: nil

  def empty_to_nil(""), do: nil
  def empty_to_nil(value), do: value
end
