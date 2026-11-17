defmodule Timeclock.Calendar.Reactors.SyncCalendarEvent do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_event_dates do
    argument :event, input(:record)

    run fn
      %{event: %Timeclock.Calendar.Event{date: %Date{}, valid_to: nil} = event}, _context ->
        {:ok, event}

      %{event: %Timeclock.Calendar.Event{date: %Date{} = d, valid_to: %Date{} = vt} = event},
      _context ->
        if Date.compare(vt, d) != :lt do
          {:ok, event}
        else
          {:error, :valid_to_before_date}
        end

      _invalid, _context ->
        {:error, :invalid_calendar_event}
    end
  end

  step :broadcast_event_updated do
    argument :event, result(:validate_event_dates)

    run fn %{event: event}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "calendar_events:#{event.group_id}",
             {:calendar_event_updated, event.id, event.date}
           ) do
        :ok ->
          {:ok, event}

        {:error, reason} ->
          Logger.warning("Failed to broadcast calendar event #{event.id}: #{inspect(reason)}")
          {:ok, event}
      end
    end
  end

  return :broadcast_event_updated
end
