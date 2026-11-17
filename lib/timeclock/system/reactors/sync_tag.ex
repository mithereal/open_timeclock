defmodule Timeclock.System.Reactors.SyncTag do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_tag_record do
    argument :tag, input(:record)

    run fn
      %{tag: %Timeclock.System.Tag{name: name} = tag}, _context
      when is_binary(name) and byte_size(name) >= 2 ->
        {:ok, tag}

      _invalid, _context ->
        {:error, :invalid_system_tag}
    end
  end

  step :broadcast_tag_updated do
    argument :tag, result(:validate_tag_record)

    run fn %{tag: tag}, _context ->
      case Phoenix.PubSub.broadcast(Timeclock.PubSub, "system:tags", {:tag_updated, tag.id, tag.name}) do
        :ok ->
          {:ok, tag}

        {:error, reason} ->
          Logger.warning("Failed to broadcast tag #{tag.id}: #{inspect(reason)}")
          {:ok, tag}
      end
    end
  end

  return :broadcast_tag_updated
end
