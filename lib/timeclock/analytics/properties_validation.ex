defmodule Timeclock.Validations.Properties do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def supports(_opts), do: [Ash.Changeset, Ash.Query]

  @impl true
  def validate(changeset, opts, _context) do
    value = get_value(changeset, opts[:properties])

    if is_nil(value) || is_map(value) do
      :ok
    else
      {:error, field: opts[:properties], message: "Properties must me a Map"}
    end
  end

  defp get_value(%Ash.Changeset{} = changeset, attribute) do
    Ash.Changeset.get_argument_or_attribute(changeset, attribute)
  end

  defp get_value(%Ash.Query{} = query, attribute) do
    Ash.Query.get_argument(query, attribute)
  end
end
