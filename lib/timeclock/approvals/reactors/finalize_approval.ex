defmodule Timeclock.Approvals.Reactors.FinalizeApproval do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_approval_signoff do
    argument :approval, input(:record)

    run fn
      %{approval: %Timeclock.Approvals.Approval{state: :approved} = approval}, _context ->
        {:ok, approval}

      _invalid, _context ->
        {:error, :approval_not_in_approved_state}
    end
  end

  step :run_lua_approval_hooks do
    argument :approval, result(:verify_approval_signoff)

    run fn %{approval: approval}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("approval.after_approve", %{approval: approval}) do
        {:ok, _payload} -> {:ok, approval}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_approval_completed do
    argument :approval, result(:run_lua_approval_hooks)

    run fn %{approval: approval}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "approvals:#{approval.user_id}",
             {:approval_completed, approval.id}
           ) do
        :ok ->
          {:ok, approval}

        {:error, reason} ->
          Logger.warning("Failed to broadcast approval #{approval.id}: #{inspect(reason)}")
          {:ok, approval}
      end
    end
  end

  return :broadcast_approval_completed
end
