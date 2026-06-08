defmodule CiBookTrackerWeb.BookFormat do
  @moduledoc false

  def status_label(:want_to_read), do: "Want to read"
  def status_label(:in_progress), do: "In progress"
  def status_label(:finished), do: "Finished"
  def status_label(:abandoned), do: "Abandoned"

  def status_class(:want_to_read), do: "bg-amber-100 text-amber-800"
  def status_class(:in_progress), do: "bg-sky-100 text-sky-800"
  def status_class(:finished), do: "bg-emerald-100 text-emerald-800"
  def status_class(:abandoned), do: "bg-slate-200 text-slate-700"

  def status_message(book, "start"), do: "Started #{book.title}."
  def status_message(book, "finish"), do: "Finished #{book.title}."
  def status_message(book, "abandon"), do: "Moved #{book.title} to abandoned."
  def status_message(book, "reopen"), do: "Reopened #{book.title}."

  def number(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> number(integer)
      _other -> value
    end
  end

  def number(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  def words(nil), do: nil
  def words(value) when value >= 1_000_000, do: "#{compact(value / 1_000_000)} million"
  def words(value) when value >= 1_000, do: "#{compact(value / 1_000)} thousand"
  def words(value), do: number(value)

  def date(nil), do: nil
  def date(value), do: Calendar.strftime(value, "%B %-d, %Y")

  defp compact(value) do
    if value == trunc(value),
      do: Integer.to_string(trunc(value)),
      else: :erlang.float_to_binary(value, decimals: 1)
  end
end
