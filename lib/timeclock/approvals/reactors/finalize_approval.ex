defmodule Timeclock.Approvals.Reactors.FinalizeApproval do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_approval_signature do
    argument :approval, input(:record)

    run fn
      %{approval: %Timeclock.Approvals.Approval{status_set_by_user_id: reviewer_id} = approval},
      _context
      when not is_nil(reviewer_id) ->
        {:ok, approval}

      %{approval: %Timeclock.Approvals.Approval{status_set_by_user_id: nil}}, _context ->
        {:error, :missing_approver_signature}

      _invalid, _context ->
        {:error, :invalid_approval_record}
    end
  end

  step :run_lua_approval_hooks do
    argument :approval, result(:verify_approval_signature)

    run fn %{approval: approval}, _context ->
      # Hook point: invoke Lua plugins subscribed to "approval.after_approve"
      {:ok, approval}
    end
  end

  step :broadcast_approval_completed do
    argument :approval, result(:run_lua_approval_hooks)

    run fn %{approval: approval}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "approvals:#{approval.user_id}",
             {:approval_completed, approval.id, approval.status}
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
