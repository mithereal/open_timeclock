defmodule Timeclock.Accounts.Reactors.SyncRole do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_role_permissions do
    argument :role, input(:record)

    run fn
      %{role: %Timeclock.Accounts.Role{name: name, permissions: perms} = role}, _context
      when is_binary(name) and is_list(perms) ->
        {:ok, role}

      _invalid, _context ->
        {:error, :invalid_role_record}
    end
  end

  step :broadcast_role_updated do
    argument :role, result(:validate_role_permissions)

    run fn %{role: role}, _context ->
      payload = %{
        id: role.id,
        name: role.name,
        permissions: role.permissions
      }

      case Phoenix.PubSub.broadcast(Timeclock.PubSub, "accounts:roles", {:role_updated, payload}) do
        :ok ->
          {:ok, role}

        {:error, reason} ->
          Logger.warning("Failed to broadcast role #{role.id}: #{inspect(reason)}")
          {:ok, role}
      end
    end
  end

  return :broadcast_role_updated
end
