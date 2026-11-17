defmodule Timeclock.Accounts.Reactors.SyncUserRole do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_assignment_keys do
    argument :user_role, input(:record)

    run fn
      %{user_role: %Timeclock.Accounts.UserRole{user_id: uid, role_id: rid} = ur}, _context
      when not is_nil(uid) and not is_nil(rid) ->
        {:ok, ur}

      _invalid, _context ->
        {:error, :invalid_user_role_assignment}
    end
  end

  step :run_lua_rbac_assignment_hooks do
    argument :user_role, result(:validate_assignment_keys)

    run fn %{user_role: ur}, _context ->
      # Hook point: notify Lua RBAC / permission cache plugins of user role change
      {:ok, ur}
    end
  end

  step :broadcast_user_role_changed do
    argument :user_role, result(:run_lua_rbac_assignment_hooks)

    run fn %{user_role: ur}, _context ->
      payload = %{
        user_id: ur.user_id,
        role_id: ur.role_id
      }

      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "accounts:users:#{ur.user_id}",
             {:user_roles_updated, payload}
           ) do
        :ok ->
          {:ok, ur}

        {:error, reason} ->
          Logger.warning("Failed to broadcast user_role for user #{ur.user_id}: #{inspect(reason)}")
          {:ok, ur}
      end
    end
  end

  return :broadcast_user_role_changed
end
