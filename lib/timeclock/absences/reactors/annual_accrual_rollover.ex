defmodule Timeclock.Absences.Reactors.AnnualAccrualRollover do
  use Ash.Reactor
  require Logger

  input :record

  step :calculate_rollover_days do
    argument :definition, input(:record)

    run fn
      %{definition: %Timeclock.Absences.Definition{active: true} = definition}, _context ->
        {:ok,
         %{
           definition_id: definition.id,
           granted_days: definition.max_days_per_year,
           fraction: definition.fraction
         }}

      %{definition: %Timeclock.Absences.Definition{active: false}}, _context ->
        {:error, :definition_inactive}

      _invalid, _context ->
        {:error, :invalid_definition_record}
    end
  end

  step :notify_rollover_complete do
    argument :rollover, result(:calculate_rollover_days)

    run fn %{rollover: rollover}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "absences:rollover",
             {:rollover_completed, rollover}
           ) do
        :ok ->
          {:ok, rollover}

        {:error, reason} ->
          Logger.warning("Failed to broadcast accrual rollover: #{inspect(reason)}")
          {:ok, rollover}
      end
    end
  end

  return :notify_rollover_complete
end
