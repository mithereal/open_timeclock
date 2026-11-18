defmodule Timeclock.Absences.Reactors.SetupDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_definition_invariants do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Absences.Definition{} = definition}, _context ->
        if definition.max_days_per_year >= 0 and definition.fraction in 1..100 do
          {:ok, definition}
        else
          {:error, :invalid_accrual_bounds}
        end

      _invalid, _context ->
        {:error, :invalid_definition_record}
    end
  end

  step :broadcast_definition_change do
    argument :definition, result(:validate_definition_invariants)

    run fn %{definition: definition}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "absence_definitions",
             {:definition_updated, definition.id}
           ) do
        :ok ->
          {:ok, definition}

        {:error, reason} ->
          Logger.warning("Failed to broadcast definition update: #{inspect(reason)}")
          {:ok, definition}
      end
    end
  end

  return :broadcast_definition_change
end
