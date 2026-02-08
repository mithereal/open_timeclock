defmodule Timeclock.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use TimeclockWeb, :verified_routes

  @impl true
  def send(user, token, _) do
    Timeclock.Mailer.Account.Confirmation.process(
      user,
      url(~p"/auth/user/confirm_new_user?#{[confirm: token]}")
    )
  end
end
