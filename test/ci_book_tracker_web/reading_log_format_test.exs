defmodule CiBookTrackerWeb.ReadingLogFormatTest do
  use ExUnit.Case, async: true

  alias CiBookTrackerWeb.ReadingLogFormat

  test "formats stored word goals with natural units" do
    assert ReadingLogFormat.format_word_goal(3_000_000) == "3 million words"
    assert ReadingLogFormat.format_word_goal(1_500_000) == "1.5 million words"
    assert ReadingLogFormat.format_word_goal(500_000) == "500 thousand words"
    assert ReadingLogFormat.format_word_goal(25_000) == "25 thousand words"
    assert ReadingLogFormat.format_word_goal(950) == "950 words"
  end

  test "returns human-readable language names" do
    assert ReadingLogFormat.language_name("es") == "Spanish"
    assert ReadingLogFormat.language_name("fr") == "French"
  end
end
