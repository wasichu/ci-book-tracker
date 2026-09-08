defmodule CiBookTracker.CsvParser do
  @moduledoc """
  Parses CSV rows, including quoted fields and normalized line endings.
  Header interpretation and book validation belong to the importer.
  """

  def parse(contents) when is_binary(contents) do
    contents
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> parse_fields([], [], "", :field_start)
  end

  defp parse_fields(<<>>, _rows, _row, _field, :quoted),
    do: {:error, ["The CSV contains an unterminated quoted field."]}

  defp parse_fields(<<>>, rows, row, field, _state) do
    rows =
      if row == [] and field == "" do
        rows
      else
        [Enum.reverse([field | row]) | rows]
      end

    {:ok, Enum.reverse(rows)}
  end

  defp parse_fields(<<"\"", rest::binary>>, rows, row, "", :field_start),
    do: parse_fields(rest, rows, row, "", :quoted)

  defp parse_fields(<<"\"\"", rest::binary>>, rows, row, field, :quoted),
    do: parse_fields(rest, rows, row, field <> "\"", :quoted)

  defp parse_fields(<<"\"", rest::binary>>, rows, row, field, :quoted),
    do: parse_fields(rest, rows, row, field, :after_quote)

  defp parse_fields(<<",", rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :after_quote],
       do: parse_fields(rest, rows, [field | row], "", :field_start)

  defp parse_fields(<<"\n", rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :after_quote],
       do: parse_fields(rest, [Enum.reverse([field | row]) | rows], [], "", :field_start)

  defp parse_fields(<<"\n", rest::binary>>, rows, row, field, :quoted),
    do: parse_fields(rest, rows, row, field <> "\n", :quoted)

  defp parse_fields(<<character::utf8, rest::binary>>, rows, row, field, :after_quote)
       when character in [?\s, ?\t],
       do: parse_fields(rest, rows, row, field, :after_quote)

  defp parse_fields(<<_character::utf8, _rest::binary>>, _rows, _row, _field, :after_quote),
    do: {:error, ["A quoted field contains unexpected text after its closing quote."]}

  defp parse_fields(<<"\"", _rest::binary>>, _rows, _row, _field, :unquoted),
    do: {:error, ["Quotes must begin at the start of a CSV field."]}

  defp parse_fields(<<character::utf8, rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :quoted] do
    next_state = if state == :field_start, do: :unquoted, else: state
    parse_fields(rest, rows, row, field <> <<character::utf8>>, next_state)
  end
end
