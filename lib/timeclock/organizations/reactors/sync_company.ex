defmodule Timeclock.Organizations.Reactors.SyncCompany do
  use Ash.Reactor
  require Logger

  input :record

  step :validate_company_entity do
    argument :company, input(:record)

    run fn
      %{company: %Timeclock.Organizations.Company{registration_number: reg} = company}, _context
      when is_binary(reg) and byte_size(reg) >= 2 ->
        {:ok, company}

      _invalid, _context ->
        {:error, :invalid_company_record}
    end
  end

  step :broadcast_company_updated do
    argument :company, result(:validate_company_entity)

    run fn %{company: company}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "organizations:#{company.organization_id}:companies",
             {:company_updated, company.id, company.name}
           ) do
        :ok ->
          {:ok, company}

        {:error, reason} ->
          Logger.warning("Failed to broadcast company #{company.id}: #{inspect(reason)}")
          {:ok, company}
      end
    end
  end

  return :broadcast_company_updated
end
