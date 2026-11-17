defmodule Timeclock.Accounts.Reactors.BroadcastTokenRevocation do
  use Ash.Reactor
  require Logger

  input :record

  step :extract_revocation_subject do
    argument :token_record, input(:record)

    run fn
      %{token_record: %Timeclock.Accounts.Token{subject: subject, purpose: purpose}}, _context
      when is_binary(subject) ->
        {:ok, %{subject: subject, purpose: purpose}}

      _invalid, _context ->
        {:error, :invalid_token_revocation_record}
    end
  end

  step :run_lua_security_audit_hooks do
    argument :revocation, result(:extract_revocation_subject)

    run fn %{revocation: revocation}, _context ->
      # Hook point: notify Lua security/SIEM audit plugins of token revocation (never pass raw JTI)
      {:ok, revocation}
    end
  end

  step :broadcast_session_revoked do
    argument :revocation, result(:run_lua_security_audit_hooks)

    run fn %{revocation: %{subject: subject} = revocation}, _context ->
      # LiveViews subscribed to "accounts:sessions:#{subject}" can force immediate disconnect
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "accounts:sessions:#{subject}",
             {:session_revoked, subject}
           ) do
        :ok ->
          {:ok, revocation}

        {:error, reason} ->
          Logger.warning("Failed to broadcast token revocation for #{subject}: #{inspect(reason)}")
          {:ok, revocation}
      end
    end
  end

  return :broadcast_session_revoked
end
