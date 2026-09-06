defmodule CiBookTrackerWeb.WordEstimatorForm do
  @moduledoc """
  Builds the sample estimator form and its display result for both the book form
  and the standalone estimator page.
  """

  alias CiBookTracker.Library.WordEstimator

  @empty_params %{
    "sample_text" => "",
    "sample_units" => "",
    "total_units" => "",
    "unit_type" => "pages"
  }

  @empty_result %{sample_words: 0, estimated_words: nil, message: nil}

  def build(params) do
    params = Map.merge(@empty_params, params)
    {Phoenix.Component.to_form(params, as: :estimator), result(params)}
  end

  defp result(params) do
    if Enum.all?(["sample_text", "sample_units", "total_units"], &(params[&1] in [nil, ""])) do
      @empty_result
    else
      case WordEstimator.evaluate(params) do
        {:ok, result} -> Map.put(result, :message, nil)
        {:error, result} -> Map.put(result, :estimated_words, nil)
      end
    end
  end
end
