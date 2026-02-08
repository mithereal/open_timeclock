defmodule Timeclock.Accounts.Generator do
  use Ash.Generator

  def role(opts \\ []) do
    seed_generator(
      %Timeclock.Accounts.Role{
        name: sequence(:title, &"Role #{&1}"),
        permissions: [sequence(:title, &"#{&1}")]
      },
      overrides: opts
    )
  end

  def user(opts \\ []) do
    seed_generator(
      %Timeclock.Accounts.User{
        email: opts[:email]
      },
      overrides: opts
    )
  end

  def account(opts \\ []) do
    user_id = opts[:user_id] || once(:default_user_id, fn -> generate(user(opts)).id end)

    changeset_generator(
      Timeclock.Accounts.Account,
      :create,
      defaults: [
        user_id: user_id
      ],
      overrides: opts
    )
  end
end
