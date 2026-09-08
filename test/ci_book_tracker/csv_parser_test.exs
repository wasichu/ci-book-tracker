defmodule CiBookTracker.CsvParserTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.CsvParser

  test "parses empty input, trailing empty fields and a final row without a newline" do
    assert CsvParser.parse("") == {:ok, []}
    assert CsvParser.parse("a,b,") == {:ok, [["a", "b", ""]]}
    assert CsvParser.parse("a,b\n") == {:ok, [["a", "b"]]}
  end

  test "normalizes line endings and preserves Unicode, quoted commas, quotes and newlines" do
    assert CsvParser.parse("title,notes\r\n\"¡Hola, señor!\",\"He said \"\"sí\"\"\rnext\"\r") ==
             {:ok, [["title", "notes"], ["¡Hola, señor!", "He said \"sí\"\nnext"]]}

    assert CsvParser.parse("\"value\" \t,next") == {:ok, [["value", "next"]]}
  end

  test "rejects malformed quoted fields with the existing errors" do
    assert CsvParser.parse("\"unfinished") ==
             {:error, ["The CSV contains an unterminated quoted field."]}

    assert CsvParser.parse("\"closed\"extra") ==
             {:error, ["A quoted field contains unexpected text after its closing quote."]}

    assert CsvParser.parse("unquoted\"") ==
             {:error, ["Quotes must begin at the start of a CSV field."]}
  end
end
