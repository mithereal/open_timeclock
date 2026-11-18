defmodule Timeclock.Organizations.Reactors.SyncOrganization do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_organization_entity do
    argument :organization, input(:record)

    run fn
      %{organization: %Timeclock.Organizations.Organization{name: name} = org}, _context
      when is_binary(name) and byte_size(name) >= 2 ->
        {:ok, org}

      _invalid, _context ->
        {:error, :invalid_organization_record}
    end
  end

  step :broadcast_organization_updated do
    argument :organization, result(:validate_organization_entity)

    run fn %{organization: org}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "organizations:#{org.id}",
             {:organization_updated, org.id, org.name}
           ) do
        :ok ->
          {:ok, org}

        {:error, reason} ->
          Logger.warning("Failed to broadcast organization #{org.id}: #{inspect(reason)}")
          {:ok, org}
      end
    end
  end

  return :broadcast_organization_updated
end
