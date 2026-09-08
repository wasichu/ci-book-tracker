defmodule CiBookTrackerWeb.BookActions do
  @moduledoc """
  Shared presentation for book actions. Each screen chooses its actions and layout.
  """

  def label("start"), do: "Start"
  def label("finish"), do: "Finish"
  def label("abandon"), do: "Abandon"
  def label("reopen"), do: "Reopen"

  def icon("start"), do: "hero-play"
  def icon("finish"), do: "hero-check"
  def icon("abandon"), do: "hero-archive-box"
  def icon("reopen"), do: "hero-arrow-path"

  def class("start"), do: "bg-sky-700 text-white hover:bg-sky-800"
  def class("finish"), do: "bg-emerald-700 text-white hover:bg-emerald-800"
  def class("abandon"), do: "bg-slate-200 text-slate-800 hover:bg-slate-300"
  def class("reopen"), do: "bg-slate-900 text-white hover:bg-amber-800"
end
