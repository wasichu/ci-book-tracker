defmodule CiBookTracker.Library.WordEstimator do
  @moduledoc """
  Counts a representative text sample and scales it to a whole-book estimate.
  """

  @word_pattern ~r/[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*/u

  def evaluate(params) do
    sample_text = Map.get(params, "sample_text", "")
    sample_words = count_words(sample_text)

    with :ok <- require_sample(sample_words),
         {:ok, sample_units} <- positive_number(params["sample_units"], "Sample unit count"),
         {:ok, total_units} <- positive_number(params["total_units"], "Total unit count"),
         :ok <- validate_unit_range(sample_units, total_units) do
      {:ok,
       %{
         sample_words: sample_words,
         estimated_words: round(sample_words / sample_units * total_units)
       }}
    else
      {:error, message} -> {:error, %{sample_words: sample_words, message: message}}
    end
  end

  def count_words(text) when is_binary(text) do
    @word_pattern
    |> Regex.scan(text)
    |> length()
  end

  def count_words(_text), do: 0

  defp require_sample(0), do: {:error, "Paste a text sample to calculate an estimate."}
  defp require_sample(_sample_words), do: :ok

  defp positive_number(value, _label) when is_number(value) and value > 0,
    do: {:ok, value / 1}

  defp positive_number(value, label) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} when number > 0 -> {:ok, number}
      _other -> {:error, "#{label} must be greater than 0."}
    end
  end

  defp positive_number(_value, label), do: {:error, "#{label} must be greater than 0."}

  defp validate_unit_range(sample_units, total_units) when total_units >= sample_units, do: :ok

  defp validate_unit_range(_sample_units, _total_units),
    do: {:error, "Total unit count must be at least the sample unit count."}
end
