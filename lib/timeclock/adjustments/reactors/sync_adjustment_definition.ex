defmodule Timeclock.Adjustments.Reactors.SyncAdjustmentDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_definition_bounds do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Adjustments.Definition{name: name} = defn}, _context
      when is_binary(name) and byte_size(name) >= 2 ->
        {:ok, defn}

      _invalid, _context ->
        {:error, :invalid_adjustment_definition}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_definition_bounds)

    run fn %{definition: defn}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "adjustment_definitions",
             {:adjustment_definition_updated, defn.id, defn.name}
           ) do
        :ok ->
          {:ok, defn}

        {:error, reason} ->
          Logger.warning("Failed to broadcast adjustment definition #{defn.id}: #{inspect(reason)}")
          {:ok, defn}
      end
    end
  end

  return :broadcast_definition_updated
end
