defmodule CiBookTrackerWeb.DashboardDataTest do
  use ExUnit.Case, async: true

  alias CiBookTrackerWeb.DashboardData

  test "summarizes only finished and in-progress books, treating missing amounts as zero" do
    books = [
      book(%{status: :finished, estimated_words: 30_000}),
      book(%{status: :finished}),
      book(%{status: :in_progress, estimated_words: 12_000, page_count: 80}),
      book(%{status: :in_progress, page_count: 20}),
      book(%{status: :want_to_read, estimated_words: 90_000}),
      book(%{status: :abandoned, estimated_words: 50_000})
    ]

    assert DashboardData.summarize(books, 40_000) == %{
             books_finished: 2,
             books_in_progress: 2,
             words_completed: 30_000,
             words_in_progress: 12_000,
             pages_in_progress: 100,
             goal_progress: 75
           }

    assert DashboardData.summarize(books, 20_000).goal_progress == 100
    assert DashboardData.summarize(books, nil).goal_progress == 0
  end

  test "empty summaries contain only zeros" do
    assert DashboardData.summarize([], nil) == %{
             books_finished: 0,
             books_in_progress: 0,
             words_completed: 0,
             words_in_progress: 0,
             pages_in_progress: 0,
             goal_progress: 0
           }
  end

  test "combines filters, matches title or author, and preserves order" do
    first =
      book(%{title: "First", author: "García", status: :in_progress, difficulty_label: " Easy "})

    second = book(%{title: "García stories", status: :finished, difficulty_label: "easy"})
    third = book(%{title: "Other", status: :in_progress, difficulty_label: "Hard"})
    books = [first, second, third]

    assert DashboardData.filter(books, "", :all, :all) == books
    assert DashboardData.filter(books, "GARCÍA", :all, :all) == [first, second]
    assert DashboardData.filter(books, "garcía", :in_progress, "EASY") == [first]
    assert DashboardData.filter(books, "missing", :all, :all) == []
  end

  test "difficulty options are trimmed, deduplicated and sorted without losing display casing" do
    books = Enum.map([" Hard ", nil, "", "  ", "Easy", "easy"], &book(%{difficulty_label: &1}))
    assert DashboardData.difficulty_options(books) == ["Easy", "Hard"]
    assert DashboardData.resolve_difficulty(" easy ", ["Easy", "Hard"]) == "Easy"
    assert DashboardData.resolve_difficulty("unknown", ["Easy"]) == :all
    assert DashboardData.resolve_difficulty("all", ["Easy"]) == :all
  end

  defp book(attributes) do
    Map.merge(
      %{
        title: "Book",
        author: nil,
        status: :want_to_read,
        difficulty_label: nil,
        estimated_words: nil,
        page_count: nil
      },
      attributes
    )
  end
end
