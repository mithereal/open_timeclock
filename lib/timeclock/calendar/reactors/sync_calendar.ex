defmodule Timeclock.Calendar.Reactors.SyncCalendar do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_calendar_invariants do
    argument :calendar, input(:record)

    run fn
      %{calendar: %Timeclock.Calendar.Calendar{work_days: [_ | _]} = cal}, _context ->
        {:ok, cal}

      _invalid, _context ->
        {:error, :invalid_calendar_record}
    end
  end

  step :run_lua_calendar_hooks do
    argument :calendar, result(:verify_calendar_invariants)

    run fn %{calendar: cal}, _context ->
      # Hook point: notify Lua scheduling/overtime plugins of work calendar update
      {:ok, cal}
    end
  end

  step :broadcast_calendar_updated do
    argument :calendar, result(:run_lua_calendar_hooks)

    run fn %{calendar: cal}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "calendars",
             {:calendar_updated, cal.id, cal.timezone}
           ) do
        :ok ->
          {:ok, cal}

        {:error, reason} ->
          Logger.warning("Failed to broadcast calendar update #{cal.id}: #{inspect(reason)}")
          {:ok, cal}
      end
    end
  end

  return :broadcast_calendar_updated
end
