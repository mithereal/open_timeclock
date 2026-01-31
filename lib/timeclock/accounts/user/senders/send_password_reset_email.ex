defmodule Timeclock.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use TimeclockWeb, :verified_routes

  @impl true
  def send(user, token, _) do
    Timeclock.Mailer.Password.Reset.process(user, url(~p"/password-reset/#{token}"))
  end
end
