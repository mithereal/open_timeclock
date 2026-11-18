defmodule Timeclock.Clocking.Reactors.SyncClockingDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_definition_pairing do
    argument :definition, input(:record)

    run fn
      %{
        definition:
          %Timeclock.Clocking.Definition{
            id: id,
            in_clocking_definition_id: in_id,
            out_clocking_definition_id: out_id
          } = defn
      },
      _context
      when id != in_id and id != out_id ->
        {:ok, defn}

      _invalid, _context ->
        {:error, :invalid_clocking_definition_pairing}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_definition_pairing)

    run fn %{definition: defn}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "clocking_definitions",
             {:clocking_definition_updated, defn.id, defn.is_active}
           ) do
        :ok ->
          {:ok, defn}

        {:error, reason} ->
          Logger.warning("Failed to broadcast clocking definition #{defn.id}: #{inspect(reason)}")
          {:ok, defn}
      end
    end
  end

  return :broadcast_definition_updated
end
