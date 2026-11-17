defmodule Timeclock.Approvals.Reactors.SyncDelegation do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_distinct_users do
    argument :delegation, input(:record)

    run fn
      %{delegation: %Timeclock.Approvals.PermissionDelegation{user_id: u, delegated_user_id: d} = del},
      _context
      when not is_nil(u) and not is_nil(d) and u != d ->
        {:ok, del}

      _invalid, _context ->
        {:error, :invalid_delegation_users}
    end
  end

  step :run_lua_delegation_hooks do
    argument :delegation, result(:validate_distinct_users)

    run fn %{delegation: del}, _context ->
      # Hook point: notify Lua approval routing plugins of delegation state change
      {:ok, del}
    end
  end

  step :broadcast_delegation_change do
    argument :delegation, result(:run_lua_delegation_hooks)

    run fn %{delegation: del}, _context ->
      topic = "approvals:delegations:#{del.delegated_user_id}"

      case Phoenix.PubSub.broadcast(Timeclock.PubSub, topic, {:delegation_updated, del.id, del.state}) do
        :ok ->
          {:ok, del}

        {:error, reason} ->
          Logger.warning("Failed to broadcast delegation #{del.id}: #{inspect(reason)}")
          {:ok, del}
      end
    end
  end

  return :broadcast_delegation_change
end
