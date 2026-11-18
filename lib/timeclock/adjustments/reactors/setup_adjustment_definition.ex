defmodule Timeclock.Adjustments.Reactors.SetupAdjustmentDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_lua_formula do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Adjustments.Definition{type: type} = definition}, _context
      when type in 0..100 ->
        # Hook point: validate any Lua plugin formula linked via definition.code_id
        {:ok, definition}

      _invalid, _context ->
        {:error, :invalid_adjustment_definition}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_lua_formula)

    run fn %{definition: definition}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "adjustment_definitions",
             {:adjustment_definition_updated, definition.id}
           ) do
        :ok ->
          {:ok, definition}

        {:error, reason} ->
          Logger.warning("Failed to broadcast adjustment definition update: #{inspect(reason)}")
          {:ok, definition}
      end
    end
  end

  return :broadcast_definition_updated
end
