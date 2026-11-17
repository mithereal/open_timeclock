defmodule Timeclock.Calendar.Reactors.SyncCalendar do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_calendar_config do
    argument :calendar, input(:record)

    run fn
      %{calendar: %Timeclock.Calendar.Calendar{time_zone: tz, workdays: wd} = cal}, _context
      when is_binary(tz) and is_map(wd) and map_size(wd) > 0 ->
        {:ok, cal}

      _invalid, _context ->
        {:error, :invalid_calendar_config}
    end
  end

  step :broadcast_calendar_updated do
    argument :calendar, result(:validate_calendar_config)

    run fn %{calendar: cal}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "calendars",
             {:calendar_updated, cal.id, cal.time_zone}
           ) do
        :ok ->
          {:ok, cal}

        {:error, reason} ->
          Logger.warning("Failed to broadcast calendar #{cal.id}: #{inspect(reason)}")
          {:ok, cal}
      end
    end
  end

  return :broadcast_calendar_updated
end
