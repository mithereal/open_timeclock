defmodule Timeclock.Scheduling.Reactors.SyncSchedule do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_schedule_window do
    argument :schedule, input(:record)

    run fn
      %{schedule: %Timeclock.Scheduling.Schedule{start_time: s, end_time: e} = sched}, _context ->
        if DateTime.compare(e, s) == :gt do
          {:ok, sched}
        else
          {:error, :invalid_schedule_window}
        end

      _invalid, _context ->
        {:error, :invalid_schedule_record}
    end
  end

  step :run_lua_scheduling_hooks do
    argument :schedule, result(:verify_schedule_window)

    run fn %{schedule: sched}, _context ->
      # Hook point: invoke Lua predictive-scheduling, clopen-check, or overtime forecast plugins
      {:ok, sched}
    end
  end

  step :broadcast_schedule_updated do
    argument :schedule, result(:run_lua_scheduling_hooks)

    run fn %{schedule: sched}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "scheduling:schedules",
             {:schedule_updated, sched.id}
           ) do
        :ok ->
          {:ok, sched}

        {:error, reason} ->
          Logger.warning("Failed to broadcast schedule #{sched.id}: #{inspect(reason)}")
          {:ok, sched}
      end
    end
  end

  return :broadcast_schedule_updated
end
