defmodule Timeclock.System.Reactors.SyncCode do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_code_format do
    argument :code, input(:record)

    run fn
      %{code: %Timeclock.System.Code{code: val} = code}, _context
      when is_binary(val) and byte_size(val) >= 1 ->
        {:ok, code}

      _invalid, _context ->
        {:error, :invalid_system_code}
    end
  end

  step :run_lua_payroll_code_hooks do
    argument :code, result(:validate_code_format)

    run fn %{code: code}, _context ->
      case Timeclock.Plugins.LuaRunner.dispatch("payroll.code_sync", %{code: code}) do
        {:ok, _payload} -> {:ok, code}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  step :broadcast_code_updated do
    argument :code, result(:run_lua_payroll_code_hooks)

    run fn %{code: code}, _context ->
      case Phoenix.PubSub.broadcast(Timeclock.PubSub, "system:codes", {:code_updated, code.id, code.code}) do
        :ok ->
          {:ok, code}

        {:error, reason} ->
          Logger.warning("Failed to broadcast code #{code.id}: #{inspect(reason)}")
          {:ok, code}
      end
    end
  end

  return :broadcast_code_updated
end
