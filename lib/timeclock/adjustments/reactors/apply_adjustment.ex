defmodule Timeclock.Adjustments.Reactors.ApplyAdjustment do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_adjustment_integrity do
    argument :adjustment, input(:record)

    run fn
      %{adjustment: %Timeclock.Adjustments.Adjustment{is_authentic: true} = adj}, _context ->
        {:ok, adj}

      %{adjustment: %Timeclock.Adjustments.Adjustment{is_authentic: false}}, _context ->
        {:error, :unauthenticated_adjustment}

      _invalid, _context ->
        {:error, :invalid_adjustment_record}
    end
  end

  step :run_lua_adjustment_hooks do
    argument :adjustment, result(:validate_adjustment_integrity)

    run fn %{adjustment: adj}, _context ->
      # Hook point: execute any Lua plugins subscribed to "adjustment.after_apply"
      {:ok, adj}
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
