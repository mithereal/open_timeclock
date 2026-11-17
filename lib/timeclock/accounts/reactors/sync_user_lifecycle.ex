defmodule Timeclock.Accounts.Reactors.SyncUserLifecycle do
  use Ash.Reactor
  require Logger

  input :record

  step :enforce_session_security do
    argument :user, input(:record)

    run fn
      %{user: %Timeclock.Accounts.User{id: id, status: :suspended} = user}, _context ->
        # Immediately revoke all stored JWT/session tokens if user is suspended
        subject = "user?id=#{id}"

        _ =
          Timeclock.Accounts.Token
          |> Ash.ActionInput.for_action(:revoke_all_stored_for_subject, %{subject: subject})
          |> Ash.run_action(authorize?: false)

        {:ok, user}

      %{user: %Timeclock.Accounts.User{} = user}, _context ->
        {:ok, user}

      _invalid, _context ->
        {:error, :invalid_user_record}
    end
  end

  step :broadcast_user_lifecycle do
    argument :user, result(:enforce_session_security)

    run fn %{user: user}, _context ->
      payload = %{
        id: user.id,
        role: user.role,
        status: user.status
      }

      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "accounts:users:#{user.id}",
             {:user_lifecycle_updated, payload}
           ) do
        :ok ->
          {:ok, user}

        {:error, reason} ->
          Logger.warning("Failed to broadcast user #{user.id}: #{inspect(reason)}")
          {:ok, user}
      end
    end
  end

  return :broadcast_user_lifecycle
end
