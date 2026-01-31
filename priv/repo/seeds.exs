seed_user = fn email ->
  {:ok, user} =
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

  user
end
