defmodule Timeclock.TimeTracking.Reactors.ProcessTimeEntry do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_geolocation_if_present do
    argument :entry, input(:record)

    run fn
      %{entry: %Timeclock.TimeTracking.TimeEntry{geolocation: nil} = entry}, _context ->
        {:ok, entry}

      %{entry: %Timeclock.TimeTracking.TimeEntry{geolocation: geo} = entry}, _context ->
        case Reactor.run(Timeclock.TimeTracking.Reactors.ValidateGeolocation, %{geolocation: geo}) do
          {:ok, _res} -> {:ok, entry}
          {:error, reason} -> {:error, reason}
        end

      _invalid, _context ->
        {:error, :invalid_time_entry_record}
    end
  end

  step :run_lua_time_entry_hooks do
    argument :entry, result(:validate_geolocation_if_present)

    run fn %{entry: entry}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("time_entry.after_record", %{entry: entry}) do
        {:ok, _payload} -> {:ok, entry}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_time_entry_recorded do
    argument :entry, result(:run_lua_time_entry_hooks)

    run fn %{entry: entry}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "time_entries:#{entry.user_id}",
             {:time_entry_recorded, entry.id, entry.direction, entry.timestamp}
           ) do
        :ok ->
          {:ok, entry}

        {:error, reason} ->
          Logger.warning("Failed to broadcast time entry #{entry.id}: #{inspect(reason)}")
          {:ok, entry}
      end
    end
  end

  return :broadcast_time_entry_recorded
end
