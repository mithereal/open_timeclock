defmodule Timeclock.Accounts.Manager do
  use Ecto.Schema
  import Ecto.Changeset

  schema "managers" do
    field :user_id, :id
    field :department_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(manager, attrs) do
    manager
    |> cast(attrs, [])
    |> validate_required([])
  end
end
