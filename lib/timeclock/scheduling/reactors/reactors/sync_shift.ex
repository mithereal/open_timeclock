defmodule Timeclock.Scheduling.Reactors.SyncShift do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_shift_template do
    argument :shift, input(:record)

    run fn
      %{shift: %Timeclock.Scheduling.Shift{start_time: s, end_time: e} = shift}, _context ->
        if Time.compare(s, e) != :eq do
          {:ok, shift}
        else
          {:error, :zero_duration_shift_template}
        end

      _invalid, _context ->
        {:error, :invalid_shift_record}
    end
  end

  step :run_lua_shift_differential_hooks do
    argument :shift, result(:validate_shift_template)

    run fn %{shift: shift}, _context ->
      # Hook point: notify Lua night-differential, break-deduction, or overtime plugins
      {:ok, shift}
    end
  end

  step :broadcast_shift_updated do
    argument :shift, result(:run_lua_shift_differential_hooks)

    run fn %{shift: shift}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "scheduling:shifts",
             {:shift_updated, shift.id, shift.name}
           ) do
        :ok ->
          {:ok, shift}

        {:error, reason} ->
          Logger.warning("Failed to broadcast shift #{shift.id}: #{inspect(reason)}")
          {:ok, shift}
      end
    end
  end

  return :broadcast_shift_updated
end
