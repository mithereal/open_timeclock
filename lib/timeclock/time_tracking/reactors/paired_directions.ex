defmodule Timeclock.TimeTracking.Calculations.PairedDirections do
  @moduledoc """
  Pairs chronological `:in` and `:out` time entries into shift intervals with durations.
  """
  use Ash.Resource.Calculation

  @impl true
  def calculate(records, _opts, %{arguments: %{entries: entries}}) when is_list(entries) do
    sorted = Enum.sort_by(entries, & &1.timestamp, DateTime)
    pairs = pair_entries(sorted, [])
    Enum.map(records, fn _record -> pairs end)
  end

  def calculate(records, _opts, _context), do: Enum.map(records, fn _ -> [] end)

  defp pair_entries([], acc), do: Enum.reverse(acc)

  defp pair_entries([%{direction: :in} = entry_in, %{direction: :out} = entry_out | rest], acc) do
    seconds = max(DateTime.diff(entry_out.timestamp, entry_in.timestamp, :second), 0)

    pair = %{
      in_id: entry_in.id,
      out_id: entry_out.id,
      started_at: entry_in.timestamp,
      ended_at: entry_out.timestamp,
      duration_seconds: seconds
    }

    pair_entries(rest, [pair | acc])
  end

  defp pair_entries([%{direction: :in} = open_in | rest], acc) do
    pair = %{
      in_id: open_in.id,
      out_id: nil,
      started_at: open_in.timestamp,
      ended_at: nil,
      duration_seconds: nil
    }

    pair_entries(rest, [pair | acc])
  end

  defp pair_entries([_unpaired_out | rest], acc), do: pair_entries(rest, acc)
end
