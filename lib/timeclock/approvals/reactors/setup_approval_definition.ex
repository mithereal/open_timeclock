defmodule Timeclock.Approvals.Reactors.SetupApprovalDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_definition_rules do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Approvals.Definition{name: name} = defn}, _context
      when is_binary(name) and byte_size(name) >= 2 ->
        {:ok, defn}

      _invalid, _context ->
        {:error, :invalid_approval_definition}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_definition_rules)

    run fn %{definition: defn}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "approval_definitions",
             {:approval_definition_updated, defn.id, defn.name}
           ) do
        :ok ->
          {:ok, defn}

        {:error, reason} ->
          Logger.warning("Failed to broadcast approval definition #{defn.id}: #{inspect(reason)}")
          {:ok, defn}
      end
    end
  end

  return :broadcast_definition_updated
end
