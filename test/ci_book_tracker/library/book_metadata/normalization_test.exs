defmodule CiBookTracker.Library.BookMetadata.NormalizationTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.Library.BookMetadata.Normalization

  test "normalizes valid ISBN values" do
    assert Normalization.isbn("978-0-307-47472-8") == "9780307474728"
    assert Normalization.isbn("123456789x") == "123456789X"
    assert Normalization.isbn("not an isbn") == nil
  end

  test "normalizes provider language codes" do
    assert Normalization.language_code("spa") == "es"
    assert Normalization.language_code("FRA") == "fr"
    assert Normalization.language_code("pt-BR") == "pt"
    assert Normalization.language_code(nil) == nil
  end

  test "normalizes positive integers without broadening provider behavior" do
    assert Normalization.positive_integer(417) == 417
    assert Normalization.positive_integer("417") == nil
    assert Normalization.positive_integer_string("417") == 417
    assert Normalization.positive_integer_string(417) == 417
    assert Normalization.positive_integer_string("0") == nil
  end

  test "normalizes optional strings and cover URLs" do
    assert Normalization.empty_to_nil("") == nil
    assert Normalization.empty_to_nil("Author") == "Author"

    assert Normalization.secure_url("http://example.com/cover.jpg") ==
             "https://example.com/cover.jpg"

    assert Normalization.secure_url("https://example.com/cover.jpg") ==
             "https://example.com/cover.jpg"
  end
end
