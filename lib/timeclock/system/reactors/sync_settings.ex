defmodule Timeclock.System.Reactors.SyncSettings do
  use Ash.Reactor
  require Logger

  input :record

  step :verify_provider_config do
    argument :settings, input(:record)

    run fn
      %{settings: %Timeclock.System.Settings{email_provider: :smtp, smtp_host: host} = settings},
      _context
      when is_binary(host) and byte_size(host) > 0 ->
        {:ok, settings}

      %{settings: %Timeclock.System.Settings{email_provider: provider} = settings}, _context
      when provider != :smtp ->
        {:ok, settings}

      _invalid, _context ->
        {:error, :incomplete_email_provider_settings}
    end
  end

  step :broadcast_settings_updated do
    argument :settings, result(:verify_provider_config)

    run fn %{settings: settings}, _context ->
      # Never include API keys or SMTP passwords in PubSub payloads
      payload = %{
        id: settings.id,
        email_provider: settings.email_provider,
        email_from_name: settings.email_from_name
      }

      case Phoenix.PubSub.broadcast(Timeclock.PubSub, "system:settings", {:settings_updated, payload}) do
        :ok ->
          {:ok, settings}

        {:error, reason} ->
          Logger.warning("Failed to broadcast settings update: #{inspect(reason)}")
          {:ok, settings}
      end
    end
  end

  return :broadcast_settings_updated
end
