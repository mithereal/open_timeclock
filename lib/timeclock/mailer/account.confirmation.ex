defmodule Timeclock.Mailer.Account.Confirmation do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        subject \\ "Account Confirmation Needed!",
        sender \\ @sender,
        domain \\ @domain
      ) do
    # url = Usher.invitation_url(user.token, "http://" <> domain <> ~p"/registration/confirm")
    url = "http://" <> domain <> ~p"/registration/confirm/#{user.token}"

    new()
    |> to({user.name, user.email})
    |> from({sender, "no-reply@#{domain}"})
    |> subject(subject)
    |> render_body("account_confirmation.html", email: user.email, url: url)
    |> premail()
    |> deliver()
  end

  def queue({name, email, token}) do
    start_time = DateTime.utc_now() |> DateTime.add(1, :minute)
    job = %{start_at: start_time, email: email, name: name, token: token}

    #  Timeclock.Workers.Mailer.Account.Confirmation.enqueue(job, :start)
  end
end
