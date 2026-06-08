defmodule CiBookTracker.Library.WordEstimatorTest do
  use ExUnit.Case, async: true

  alias CiBookTracker.Library.WordEstimator

  test "counts English and Spanish words with accents and apostrophes" do
    assert WordEstimator.count_words("¡Hola, señor! L'été isn't over.") == 5
  end

  test "scales a sample across the full unit count" do
    sample = Enum.map_join(1..1_200, " ", &"palabra#{&1}")

    assert {:ok, %{sample_words: 1_200, estimated_words: 43_200}} =
             WordEstimator.evaluate(%{
               "sample_text" => sample,
               "sample_units" => "5",
               "total_units" => "180"
             })
  end

  test "rejects invalid unit ranges" do
    assert {:error, %{message: "Total unit count must be at least the sample unit count."}} =
             WordEstimator.evaluate(%{
               "sample_text" => "one two three",
               "sample_units" => "10",
               "total_units" => "5"
             })
  end
end
