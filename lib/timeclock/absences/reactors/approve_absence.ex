defmodule Timeclock.Absences.Reactors.ApproveAbsence do
  use Ash.Reactor

  input :record

  step :validate_accrual_balance do
    argument :absence, input(:record)

    run fn %{absence: absence}, _context ->
      # Check PTO/sick balance; return {:error, :insufficient_balance} to halt & rollback
      {:ok, %{validated: true, absence_id: absence.id}}
    end
  end

  step :run_lua_absence_hooks do
    argument :absence, input(:record)
    wait_for :validate_accrual_balance

    run fn %{absence: absence}, _context ->
      # Invoke your Lua sandbox hook: "absence.after_approve"
      {:ok, absence}
    end
  end

  step :broadcast_update do
    argument :absence, input(:record)
    wait_for :run_lua_absence_hooks

    run fn %{absence: absence}, _context ->
      Phoenix.PubSub.broadcast(
        Timeclock.PubSub,
        "absences:#{absence.user_id}",
        {:absence_approved, absence.id}
      )

      {:ok, absence}
    end
  end

  return :broadcast_update
end
