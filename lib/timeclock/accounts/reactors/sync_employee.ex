defmodule Timeclock.Accounts.Reactors.SyncEmployee do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_employee_record do
    argument :employee, input(:record)

    run fn
      %{employee: %Timeclock.Accounts.Employee{position: pos, department_id: dept_id} = employee},
      _context
      when is_binary(pos) and byte_size(pos) >= 2 and not is_nil(dept_id) ->
        {:ok, employee}

      _invalid, _context ->
        {:error, :invalid_employee_record}
    end
  end

  step :run_lua_employee_hooks do
    argument :employee, result(:validate_employee_record)

    run fn %{employee: employee}, _context ->
      # Hook point: invoke Lua accrual-tier, department-routing, or payroll plugins
      {:ok, employee}
    end
  end

  step :broadcast_employee_updated do
    argument :employee, result(:run_lua_employee_hooks)

    run fn %{employee: employee}, _context ->
      payload = %{
        id: employee.id,
        user_id: employee.user_id,
        department_id: employee.department_id,
        position: employee.position,
        state: employee.state
      }

      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "departments:#{employee.department_id}:employees",
             {:employee_updated, payload}
           ) do
        :ok ->
          {:ok, employee}

        {:error, reason} ->
          Logger.warning("Failed to broadcast employee #{employee.id}: #{inspect(reason)}")
          {:ok, employee}
      end
    end
  end

  return :broadcast_employee_updated
end
