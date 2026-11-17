defmodule Timeclock.Clocking.Reactors.ProcessClockingPunch do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_lua_punch_rules do
    argument :clocking, input(:record)

    run fn
      %{clocking: %Timeclock.Clocking.Clocking{} = clocking}, _context ->
        # Hook point: run Lua geofence, shift-window, or device plugins ("punch.before_verify")
        # Return {:error, :outside_geofence} to automatically transition the workflow to :flagged
        {:ok, clocking}

      _invalid, _context ->
        {:error, :invalid_clocking_record}
    end
  end

  step :sync_time_entry do
    argument :clocking, result(:validate_lua_punch_rules)

    run fn %{clocking: clocking}, _context ->
      # Hook point: open or close the corresponding Timeclock.TimeTracking.TimeEntry
      {:ok, clocking}
    end
  end

  step :broadcast_live_punch do
    argument :clocking, result(:sync_time_entry)

    run fn %{clocking: clocking}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "clockings:live",
             {:punch_recorded, clocking.id, clocking.user_id, clocking.punched_at}
           ) do
        :ok ->
          {:ok, clocking}

        {:error, reason} ->
          Logger.warning("Failed to broadcast clocking #{clocking.id}: #{inspect(reason)}")
          {:ok, clocking}
      end
    end
  end

  return :broadcast_live_punch
end
