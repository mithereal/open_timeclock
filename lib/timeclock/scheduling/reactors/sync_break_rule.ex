defmodule Timeclock.Scheduling.Reactors.SyncBreakRule do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_break_rule_bounds do
    argument :rule, input(:record)

    run fn
      %{rule: %Timeclock.Scheduling.BreakRule{duration_minutes: mins} = rule}, _context
      when is_integer(mins) and mins in 1..480 ->
        {:ok, rule}

      _invalid, _context ->
        {:error, :invalid_break_rule}
    end
  end

  step :run_lua_break_compliance_hooks do
    argument :rule, result(:validate_break_rule_bounds)

    run fn %{rule: rule}, _context ->
      # Hook point: notify Lua meal/rest break compliance & auto-deduction plugins
      {:ok, rule}
    end
  end

  step :broadcast_break_rule_updated do
    argument :rule, result(:run_lua_break_compliance_hooks)

    run fn %{rule: rule}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "scheduling:break_rules",
             {:break_rule_updated, rule.id, rule.name}
           ) do
        :ok ->
          {:ok, rule}

        {:error, reason} ->
          Logger.warning("Failed to broadcast break rule #{rule.id}: #{inspect(reason)}")
          {:ok, rule}
      end
    end
  end

  return :broadcast_break_rule_updated
end
