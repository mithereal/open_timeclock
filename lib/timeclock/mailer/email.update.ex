defmodule Timeclock.Mailer.Email.Update do
  use Timeclock.Mailer, :premailx

  def process(user, subject \\ "Account Action Needed!", sender \\ @sender, domain \\ @domain) do
    url = ~p"/user/settings/confirm_email/#{user.token}"

    new()
    |> to({user.name, user.email})
    |> from({sender, "no-reply@#{domain}"})
    |> subject(subject)
    |> render_body("email_update.html", %{username: user.name, url: url})
    |> premail()
    |> deliver()
  end

  def queue({name, email, token}) do
    start_time = DateTime.utc_now() |> DateTime.add(1, :minute)
    job = %{start_at: start_time, email: email, name: name, token: token}

    #  Timeclock.Workers.Mailer.Email.Update.enqueue(job, :start)
  end
end
