defmodule Timeclock.Accounts.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :position, :string
    field :hired_at, :utc_datetime
    field :user_id, :id
    field :department_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [:position, :hired_at])
    |> validate_required([:position, :hired_at])
  end
end
