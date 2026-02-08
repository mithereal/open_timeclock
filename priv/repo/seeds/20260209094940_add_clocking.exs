defmodule Timeclock.Repo.Seeds.AddClocking do
  use Timeclock.Seed

  envs([:dev])

  def insert(timestamp, user) do
    Timeclock.Clocking.Clocking
    |> Ash.Changeset.for_create(:insert_from_web, %{
      timestamp: timestamp,
      user: user
    })
    |> Ash.create()
  end

  def up(_repo) do
    {:ok, users} = Timeclock.Accounts.list_users()

    Enum.each(users, fn user ->
      datetime = DateTime.utc_now()
      __MODULE__.insert(datetime, user)
    end)
  end
end
