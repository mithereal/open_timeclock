defmodule Timeclock.Absences.Reactors.ApproveAbsence do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_approval_state do
    argument :absence, input(:record)

    run fn
      %{absence: %Timeclock.Absences.Absence{state: :approved} = absence}, _context ->
        {:ok, absence}

      _invalid, _context ->
        {:error, :absence_not_in_approved_state}
    end
  end

  step :run_lua_absence_hooks do
    argument :absence, result(:verify_approval_state)

    run fn %{absence: absence}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("absence.after_approve", %{absence: absence}) do
        {:ok, _payload} -> {:ok, absence}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_absence_approved do
    argument :absence, result(:run_lua_absence_hooks)

    run fn %{absence: absence}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "absences:#{absence.user_id}",
             {:absence_approved, absence.id}
           ) do
        :ok ->
          {:ok, absence}

        {:error, reason} ->
          Logger.warning("Failed to broadcast absence approval #{absence.id}: #{inspect(reason)}")
          {:ok, absence}
      end
    end
  end

  return :broadcast_absence_approved
end
