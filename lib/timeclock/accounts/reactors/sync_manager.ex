defmodule Timeclock.Accounts.Reactors.SyncManager do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_manager_assignment do
    argument :manager, input(:record)

    run fn
      %{manager: %Timeclock.Accounts.Manager{user_id: u_id, department_id: d_id} = manager},
      _context
      when not is_nil(u_id) and not is_nil(d_id) ->
        {:ok, manager}

      _invalid, _context ->
        {:error, :invalid_manager_assignment}
    end
  end

  step :broadcast_manager_updated do
    argument :manager, result(:validate_manager_assignment)

    run fn %{manager: manager}, _context ->
      payload = %{
        id: manager.id,
        user_id: manager.user_id,
        department_id: manager.department_id
      }

      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "departments:#{manager.department_id}:managers",
             {:manager_updated, payload}
           ) do
        :ok ->
          {:ok, manager}

        {:error, reason} ->
          Logger.warning("Failed to broadcast manager #{manager.id}: #{inspect(reason)}")
          {:ok, manager}
      end
    end
  end

  return :broadcast_manager_updated
end
