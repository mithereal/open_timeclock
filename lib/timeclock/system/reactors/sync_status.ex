defmodule Timeclock.System.Reactors.SyncStatus do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_status_semantics do
    argument :status, input(:record)

    run fn
      %{
        status:
          %Timeclock.System.Status{
            presence_status: presence,
            paid_time_status: paid
          } = status
      },
      _context
      when presence in ["present", "absent", "neutral", "on_break"] and
             paid in ["paid", "unpaid", "partial"] ->
        {:ok, status}

      _invalid, _context ->
        {:error, :invalid_status_semantics}
    end
  end

  step :broadcast_status_updated do
    argument :status, result(:validate_status_semantics)

    run fn %{status: status}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "system:statuses",
             {:status_updated, status.id, status.name, status.presence_status}
           ) do
        :ok ->
          {:ok, status}

        {:error, reason} ->
          Logger.warning("Failed to broadcast status #{status.id}: #{inspect(reason)}")
          {:ok, status}
      end
    end
  end

  return :broadcast_status_updated
end
