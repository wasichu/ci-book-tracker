defmodule CiBookTracker.Library.BookCsvImport do
  @moduledoc false

  alias CiBookTracker.Library

  @columns ~w(
    title
    author
    status
    page_count
    estimated_words
    difficulty_label
    started_on
    finished_on
    notes
  )
  @statuses ~w(want_to_read in_progress finished abandoned)

  defmodule Row do
    @moduledoc false
    defstruct [:number, :values, :attributes, errors: []]
  end

  def preview(contents, today \\ Date.utc_today()) when is_binary(contents) do
    with {:ok, rows} <- parse_csv(contents),
         {:ok, headers, data_rows} <- split_headers(rows),
         :ok <- validate_headers(headers) do
      rows =
        data_rows
        |> Enum.with_index(2)
        |> Enum.reject(fn {fields, _number} -> Enum.all?(fields, &(String.trim(&1) == "")) end)
        |> Enum.map(fn {fields, number} -> validate_row(fields, headers, number, today) end)

      {:ok,
       %{
         rows: rows,
         valid_count: Enum.count(rows, &(&1.errors == [])),
         invalid_count: Enum.count(rows, &(&1.errors != []))
       }}
    end
  end

  def import(%{rows: rows}, reading_log_id) do
    rows
    |> Enum.filter(&(&1.errors == []))
    |> Enum.reduce(%{imported: 0, failed: []}, fn row, summary ->
      title = row.attributes.title
      attributes = Map.delete(row.attributes, :title)

      case Library.add_book(reading_log_id, title, attributes) do
        {:ok, _book} ->
          %{summary | imported: summary.imported + 1}

        {:error, error} ->
          failure = %{row: row.number, title: title, reason: Exception.message(error)}
          %{summary | failed: [failure | summary.failed]}
      end
    end)
    |> Map.update!(:failed, &Enum.reverse/1)
  end

  defp split_headers([]), do: {:error, ["The CSV file is empty."]}

  defp split_headers([headers | data_rows]) do
    headers =
      headers
      |> Enum.with_index()
      |> Enum.map(fn
        {header, 0} -> header |> String.trim_leading("\uFEFF") |> normalize_header()
        {header, _index} -> normalize_header(header)
      end)

    {:ok, headers, data_rows}
  end

  defp normalize_header(header), do: header |> String.trim() |> String.downcase()

  defp validate_headers(headers) do
    errors =
      []
      |> maybe_add("The CSV must include a title column.", "title" not in headers)
      |> maybe_add(
        "Duplicate column names are not allowed.",
        length(headers) != length(Enum.uniq(headers))
      )
      |> maybe_add(
        "Unknown columns: #{unknown_columns(headers) |> Enum.join(", ")}.",
        unknown_columns(headers) != []
      )

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp unknown_columns(headers), do: headers -- @columns

  defp validate_row(fields, headers, number, today) do
    values =
      headers
      |> Enum.zip(fields ++ List.duplicate("", max(length(headers) - length(fields), 0)))
      |> Map.new()

    errors =
      []
      |> maybe_add("has more values than the header row", length(fields) > length(headers))
      |> validate_required(values, "title")
      |> validate_status(values)
      |> validate_integer(values, "page_count")
      |> validate_integer(values, "estimated_words")
      |> validate_date(values, "started_on")
      |> validate_date(values, "finished_on")

    %Row{
      number: number,
      values: values,
      attributes: attributes(values, today),
      errors: Enum.reverse(errors)
    }
  end

  defp validate_required(errors, values, key) do
    maybe_add(errors, "#{key} is required", blank?(values[key]))
  end

  defp validate_status(errors, values) do
    status = trimmed(values["status"])

    maybe_add(
      errors,
      "status must be one of #{Enum.join(@statuses, ", ")}",
      status != "" and status not in @statuses
    )
  end

  defp validate_integer(errors, values, key) do
    value = trimmed(values[key])

    maybe_add(
      errors,
      "#{key} must be a positive whole number",
      value != "" and not positive_integer?(value)
    )
  end

  defp validate_date(errors, values, key) do
    value = trimmed(values[key])

    maybe_add(
      errors,
      "#{key} must use YYYY-MM-DD",
      value != "" and not match?({:ok, _date}, Date.from_iso8601(value))
    )
  end

  defp attributes(values, today) do
    status = parse_status(values["status"])
    page_count = parse_integer(values["page_count"])
    estimated_words = parse_integer(values["estimated_words"]) || estimate_words(page_count)
    finished_on = parse_date(values["finished_on"]) || default_finished_on(status, today)
    started_on = parse_date(values["started_on"]) || default_started_on(status, finished_on)

    %{
      title: trimmed(values["title"]),
      author: optional_string(values["author"]),
      status: status,
      page_count: page_count,
      estimated_words: estimated_words,
      difficulty_label: optional_string(values["difficulty_label"]),
      started_on: started_on,
      finished_on: finished_on,
      notes: optional_string(values["notes"])
    }
  end

  defp parse_status(value) do
    case trimmed(value) do
      "in_progress" -> :in_progress
      "finished" -> :finished
      "abandoned" -> :abandoned
      _other -> :want_to_read
    end
  end

  defp parse_integer(value) do
    case Integer.parse(trimmed(value)) do
      {integer, ""} when integer > 0 -> integer
      _other -> nil
    end
  end

  defp parse_date(value) do
    case Date.from_iso8601(trimmed(value)) do
      {:ok, date} -> date
      _other -> nil
    end
  end

  defp estimate_words(nil), do: nil
  defp estimate_words(page_count), do: page_count * 250

  defp default_finished_on(:finished, today), do: today
  defp default_finished_on(_status, _today), do: nil

  defp default_started_on(:finished, finished_on), do: finished_on
  defp default_started_on(_status, _finished_on), do: nil

  defp optional_string(value) do
    case trimmed(value) do
      "" -> nil
      value -> value
    end
  end

  defp positive_integer?(value), do: match?({integer, ""} when integer > 0, Integer.parse(value))
  defp blank?(value), do: trimmed(value) == ""
  defp trimmed(nil), do: ""
  defp trimmed(value), do: String.trim(value)

  defp maybe_add(errors, _message, false), do: errors
  defp maybe_add(errors, message, true), do: [message | errors]

  defp parse_csv(contents) do
    contents
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> do_parse_csv([], [], "", :field_start)
  end

  defp do_parse_csv(<<>>, _rows, _row, _field, :quoted),
    do: {:error, ["The CSV contains an unterminated quoted field."]}

  defp do_parse_csv(<<>>, rows, row, field, _state) do
    rows =
      if row == [] and field == "" do
        rows
      else
        [Enum.reverse([field | row]) | rows]
      end

    {:ok, Enum.reverse(rows)}
  end

  defp do_parse_csv(<<"\"", rest::binary>>, rows, row, "", :field_start),
    do: do_parse_csv(rest, rows, row, "", :quoted)

  defp do_parse_csv(<<"\"\"", rest::binary>>, rows, row, field, :quoted),
    do: do_parse_csv(rest, rows, row, field <> "\"", :quoted)

  defp do_parse_csv(<<"\"", rest::binary>>, rows, row, field, :quoted),
    do: do_parse_csv(rest, rows, row, field, :after_quote)

  defp do_parse_csv(<<",", rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :after_quote],
       do: do_parse_csv(rest, rows, [field | row], "", :field_start)

  defp do_parse_csv(<<"\n", rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :after_quote],
       do: do_parse_csv(rest, [Enum.reverse([field | row]) | rows], [], "", :field_start)

  defp do_parse_csv(<<"\n", rest::binary>>, rows, row, field, :quoted),
    do: do_parse_csv(rest, rows, row, field <> "\n", :quoted)

  defp do_parse_csv(<<character::utf8, rest::binary>>, rows, row, field, :after_quote)
       when character in [?\s, ?\t],
       do: do_parse_csv(rest, rows, row, field, :after_quote)

  defp do_parse_csv(<<_character::utf8, _rest::binary>>, _rows, _row, _field, :after_quote),
    do: {:error, ["A quoted field contains unexpected text after its closing quote."]}

  defp do_parse_csv(<<"\"", _rest::binary>>, _rows, _row, _field, :unquoted),
    do: {:error, ["Quotes must begin at the start of a CSV field."]}

  defp do_parse_csv(<<character::utf8, rest::binary>>, rows, row, field, state)
       when state in [:field_start, :unquoted, :quoted] do
    next_state = if state == :field_start, do: :unquoted, else: state
    do_parse_csv(rest, rows, row, field <> <<character::utf8>>, next_state)
  end
end
