defmodule Timeclock.Accounts.Reactors.SyncAccount do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_account_invariants do
    argument :account, input(:record)

    run fn
      %{account: %Timeclock.Accounts.Account{custom_id: cid, assigned_pin: pin} = account}, _context
      when is_binary(cid) and is_integer(pin) and pin >= 1000 ->
        {:ok, account}

      _invalid, _context ->
        {:error, :invalid_account_record}
    end
  end

  step :run_lua_hr_sync_hooks do
    argument :account, result(:validate_account_invariants)

    run fn %{account: account}, _context ->
      # Hook point: invoke Lua HRIS, badge-reader, or payroll employee sync plugins
      {:ok, account}
    end
  end

  step :broadcast_account_updated do
    argument :account, result(:run_lua_hr_sync_hooks)

    run fn %{account: account}, _context ->
      # Never include sensitive assigned_pin in PubSub payloads
      payload = %{
        id: account.id,
        custom_id: account.custom_id,
        is_archived: account.is_archived,
        state: account.state
      }

      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "accounts:#{account.id}",
             {:account_updated, payload}
           ) do
        :ok ->
          {:ok, account}

        {:error, reason} ->
          Logger.warning("Failed to broadcast account #{account.id}: #{inspect(reason)}")
          {:ok, account}
      end
    end
  end

  return :broadcast_account_updated
end