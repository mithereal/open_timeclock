defmodule Timeclock.Notifiers.EmailNotifier do
  use Ash.Notifier
  # alias Timeclock.Accounts.User

  @impl true
  def notify(%Ash.Notifier.Notification{action: %{name: :change_password}, data: _user}) do
    # User.Email.deliver_password_change_notification(user)
  end
end
