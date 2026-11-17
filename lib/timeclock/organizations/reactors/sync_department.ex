defmodule Timeclock.Organizations.Reactors.SyncDepartment do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_department_defaults do
    argument :department, input(:record)

    run fn
      %{
        department:
          %Timeclock.Organizations.Department{
            in_clocking_definition_id: in_id,
            out_clocking_definition_id: out_id
          } = dept
      },
      _context
      when is_nil(in_id) or in_id != out_id ->
        {:ok, dept}

      _invalid, _context ->
        {:error, :invalid_department_clocking_defaults}
    end
  end

  step :broadcast_department_updated do
    argument :department, result(:validate_department_defaults)

    run fn %{department: dept}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "companies:#{dept.company_id}:departments",
             {:department_updated, dept.id, dept.name}
           ) do
        :ok ->
          {:ok, dept}

        {:error, reason} ->
          Logger.warning("Failed to broadcast department #{dept.id}: #{inspect(reason)}")
          {:ok, dept}
      end
    end
  end

  return :broadcast_department_updated
end
