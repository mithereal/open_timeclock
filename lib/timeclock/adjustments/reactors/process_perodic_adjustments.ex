defmodule Timeclock.Adjustments.Reactors.ProcessPeriodicAdjustment do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_adjustment_invariants do
    argument :adjustment, input(:record)

    run fn
      %{adjustment: %Timeclock.Adjustments.Adjustment{value: val} = adj}, _context
      when is_number(val) and val != 0 ->
        {:ok, adj}

      _invalid, _context ->
        {:error, :invalid_adjustment_amount}
    end
  end

  step :run_lua_adjustment_hooks do
    argument :adjustment, result(:validate_adjustment_invariants)

    run fn %{adjustment: adj}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("adjustment.periodic", %{adjustment: adj}) do
        {:ok, _payload} -> {:ok, adj}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_adjustment_applied do
    argument :adjustment, result(:run_lua_adjustment_hooks)

    run fn %{adjustment: adj}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "adjustments:#{adj.account_id}",
             {:adjustment_applied, adj.id, adj.value}
           ) do
        :ok ->
          {:ok, adj}

        {:error, reason} ->
          Logger.warning("Failed to broadcast adjustment #{adj.id}: #{inspect(reason)}")
          {:ok, adj}
      end
    end
  end

  return :broadcast_adjustment_applied
end
