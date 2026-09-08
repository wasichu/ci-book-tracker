defmodule CiBookTrackerWeb.DashboardData do
  @moduledoc "Pure summary and filtering calculations for the reading dashboard."

  def summarize(books, word_goal) do
    books_finished = Enum.count(books, &(&1.status == :finished))
    books_in_progress = Enum.count(books, &(&1.status == :in_progress))

    words_completed =
      books
      |> Enum.filter(&(&1.status == :finished))
      |> Enum.map(&(&1.estimated_words || 0))
      |> Enum.sum()

    in_progress_books = Enum.filter(books, &(&1.status == :in_progress))

    words_in_progress =
      in_progress_books
      |> Enum.map(&(&1.estimated_words || 0))
      |> Enum.sum()

    pages_in_progress =
      in_progress_books
      |> Enum.map(&(&1.page_count || 0))
      |> Enum.sum()

    %{
      books_finished: books_finished,
      books_in_progress: books_in_progress,
      words_in_progress: words_in_progress,
      pages_in_progress: pages_in_progress,
      words_completed: words_completed,
      goal_progress: goal_progress(words_completed, word_goal)
    }
  end

  defp goal_progress(_words_completed, nil), do: 0

  defp goal_progress(words_completed, word_goal),
    do: min(round(words_completed / word_goal * 100), 100)

  @doc "Filters books without changing their order or the dashboard totals."
  def filter(books, query, status_filter, difficulty_filter) do
    query = query |> String.trim() |> String.downcase()

    Enum.filter(books, fn book ->
      status_matches? = status_filter == :all || book.status == status_filter
      search_matches? = query == "" || book_matches_search?(book, query)

      difficulty_matches? =
        difficulty_filter == :all ||
          normalized_difficulty(book.difficulty_label) == normalized_difficulty(difficulty_filter)

      status_matches? && search_matches? && difficulty_matches?
    end)
  end

  def resolve_difficulty("all", _options), do: :all

  def resolve_difficulty(difficulty, options) do
    Enum.find(options, :all, fn option ->
      normalized_difficulty(option) == normalized_difficulty(difficulty)
    end)
  end

  defp book_matches_search?(book, query) do
    String.contains?(String.downcase(book.title), query) ||
      String.contains?(String.downcase(book.author || ""), query)
  end

  def difficulty_options(books) do
    books
    |> Enum.map(& &1.difficulty_label)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&normalized_difficulty/1)
    |> Enum.sort_by(&normalized_difficulty/1)
  end

  defp normalized_difficulty(value),
    do: value |> to_string() |> String.trim() |> String.downcase()
end
