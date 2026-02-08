defmodule Timeclock.Repo.Seeds.AddUsers do
  use Timeclock.Seed

  envs([:dev])
  @params ["admin@example.com"]

  def insert(email) do
    Timeclock.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "timeclock",
      password_confirmation: "timeclock"
    })
    |> Ash.create(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )
  end

  def up(_repo) do
    Enum.each(@params, fn email -> __MODULE__.insert(email) end)
  end
end
