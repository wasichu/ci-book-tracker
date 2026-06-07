defmodule CiBookTrackerWeb.ReadingLogFormat do
  @moduledoc false

  @languages [
    {"Spanish", "es"},
    {"French", "fr"},
    {"German", "de"},
    {"Italian", "it"},
    {"Portuguese", "pt"},
    {"Japanese", "ja"},
    {"Korean", "ko"},
    {"Chinese", "zh"},
    {"Arabic", "ar"},
    {"Russian", "ru"},
    {"Hindi", "hi"},
    {"Dutch", "nl"},
    {"Swedish", "sv"},
    {"Greek", "el"},
    {"Latin", "la"}
  ]

  def language_options, do: @languages

  def language_name(code) do
    case List.keyfind(@languages, code, 1) do
      {name, _code} -> name
      nil -> String.upcase(code)
    end
  end

  def format_word_goal(word_goal) when word_goal >= 1_000_000 do
    "#{format_scaled(word_goal, 1_000_000)} million words"
  end

  def format_word_goal(word_goal) when word_goal >= 1_000 do
    "#{format_scaled(word_goal, 1_000)} thousand words"
  end

  def format_word_goal(word_goal), do: "#{word_goal} words"

  defp format_scaled(value, divisor) do
    if rem(value, divisor) == 0 do
      Integer.to_string(div(value, divisor))
    else
      value
      |> Kernel./(divisor)
      |> :erlang.float_to_binary(decimals: 2)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    end
  end
end
