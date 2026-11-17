defmodule Timeclock.Approvals.Reactors.SetupApprovalDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_parameter_rules do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Approvals.Definition{end_time_parameter_required: true, start_time_parameter_required: false}},
      _context ->
        {:error, :end_time_requires_start_time}

      %{definition: %Timeclock.Approvals.Definition{} = definition}, _context ->
        {:ok, definition}

      _invalid, _context ->
        {:error, :invalid_approval_definition}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_parameter_rules)

    run fn %{definition: definition}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "approval_definitions",
             {:approval_definition_updated, definition.id}
           ) do
        :ok ->
          {:ok, definition}

        {:error, reason} ->
          Logger.warning("Failed to broadcast approval definition update: #{inspect(reason)}")
          {:ok, definition}
      end
    end
  end

  return :broadcast_definition_updated
end
