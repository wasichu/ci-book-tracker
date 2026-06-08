defmodule CiBookTrackerWeb.BookFormatTest do
  use ExUnit.Case, async: true

  alias CiBookTrackerWeb.BookFormat

  test "formats numbers from integer and form string values" do
    assert BookFormat.number(1_234_567) == "1,234,567"
    assert BookFormat.number("27000") == "27,000"
    assert BookFormat.number("") == ""
  end

  test "formats compact word totals consistently" do
    assert BookFormat.words(nil) == nil
    assert BookFormat.words(950) == "950"
    assert BookFormat.words(27_000) == "27 thousand"
    assert BookFormat.words(59_250) == "59.3 thousand"
    assert BookFormat.words(1_500_000) == "1.5 million"
  end

  test "formats statuses and transition messages" do
    book = %{title: "Cien anos de soledad"}

    assert BookFormat.status_label(:want_to_read) == "Want to read"
    assert BookFormat.status_label(:in_progress) == "In progress"
    assert BookFormat.status_class(:finished) == "bg-emerald-100 text-emerald-800"
    assert BookFormat.status_message(book, "finish") == "Finished Cien anos de soledad."
  end

  test "formats optional dates" do
    assert BookFormat.date(nil) == nil
    assert BookFormat.date(~D[2026-06-08]) == "June 8, 2026"
  end
end
