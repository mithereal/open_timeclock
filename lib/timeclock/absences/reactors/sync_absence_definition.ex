defmodule Timeclock.Absences.Reactors.SyncAbsenceDefinition do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_definition_bounds do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Absences.Definition{max_days_per_year: max_days, fraction: frac} = defn},
      _context
      when max_days > 0 and frac in 1..100 ->
        {:ok, defn}

      _invalid, _context ->
        {:error, :invalid_absence_definition_bounds}
    end
  end

  step :broadcast_definition_updated do
    argument :definition, result(:validate_definition_bounds)

    run fn %{definition: defn}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "absence_definitions",
             {:absence_definition_updated, defn.id, defn.name}
           ) do
        :ok ->
          {:ok, defn}

        {:error, reason} ->
          Logger.warning("Failed to broadcast absence definition #{defn.id}: #{inspect(reason)}")
          {:ok, defn}
      end
    end
  end

  return :broadcast_definition_updated
end
