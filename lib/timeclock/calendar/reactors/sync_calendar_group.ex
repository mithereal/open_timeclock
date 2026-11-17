defmodule Timeclock.Calendar.Reactors.SyncCalendarGroup do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_group_structure do
    argument :group, input(:record)

    run fn
      %{group: %Timeclock.Calendar.Group{workdays: wd} = group}, _context
      when is_map(wd) and map_size(wd) > 0 ->
        {:ok, group}

      _invalid, _context ->
        {:error, :invalid_calendar_group}
    end
  end

  step :run_lua_group_hooks do
    argument :group, result(:validate_group_structure)

    run fn %{group: group}, _context ->
      # Hook point: notify Lua scheduling/holiday plugins of calendar group change
      {:ok, group}
    end
  end

  step :broadcast_group_updated do
    argument :group, result(:run_lua_group_hooks)

    run fn %{group: group}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "calendar_groups",
             {:calendar_group_updated, group.id, group.time_zone}
           ) do
        :ok ->
          {:ok, group}

        {:error, reason} ->
          Logger.warning("Failed to broadcast calendar group #{group.id}: #{inspect(reason)}")
          {:ok, group}
      end
    end
  end

  return :broadcast_group_updated
end
