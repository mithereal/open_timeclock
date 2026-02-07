@status [{"Work From Home", "blue"}, {"Depart", "red"}]
@users ["test@example.com"]

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

seed_status = fn name, color ->
  {:ok, reply} =
    Timeclock.System.Status
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      color: color
    })
    |> Ash.create()

  reply
end

_admin_user = seed_user.("test@example.com")
_status = seed_status.("Work from Home", "blue")
