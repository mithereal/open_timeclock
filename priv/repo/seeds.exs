@status [{"Work From Home", "blue"}, {"Depart", "red"}]
@users ["admin@example.com"]

seed_user = fn email ->
  {:ok, reply} =
    Timeclock.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "Aa123123123123",
      password_confirmation: "Aa123123123123"
    })
    |> Ash.create(
      context: %{
        strategy: AshAuthentication.Strategy.Password,
        private: %{ash_authentication?: true}
      }
    )

  reply
end

_admin_user = seed_user.("admin@example.com")
_status = seed_status.("Work from Home", "blue")
