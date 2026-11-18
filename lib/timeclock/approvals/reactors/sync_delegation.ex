defmodule Timeclock.Approvals.Reactors.SyncDelegation do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_delegation_invariants do
    argument :delegation, input(:record)

    run fn
      %{delegation: %Timeclock.Approvals.PermissionDelegation{user_id: uid, delegated_user_id: did} = del},
      _context
      when not is_nil(uid) and not is_nil(did) and uid != did ->
        {:ok, del}

      _invalid, _context ->
        {:error, :invalid_delegation_record}
    end
  end

  step :run_lua_delegation_hooks do
    argument :delegation, result(:validate_delegation_invariants)

    run fn %{delegation: del}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("delegation.updated", %{delegation: del}) do
        {:ok, _payload} -> {:ok, del}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_delegation_updated do
    argument :delegation, result(:run_lua_delegation_hooks)

    run fn %{delegation: del}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "approvals:delegations:#{del.delegated_user_id}",
             {:delegation_updated, del.id, del.state}
           ) do
        :ok ->
          {:ok, del}

        {:error, reason} ->
          Logger.warning("Failed to broadcast delegation #{del.id}: #{inspect(reason)}")
          {:ok, del}
      end
    end
  end

  return :broadcast_delegation_updated
end
