defmodule Timeclock.Mailer.Welcome do
  use Timeclock.Mailer, :premailx

  def process(user, subject \\ "Welcome to our Site!", sender \\ @sender, domain \\ @domain) do
    new()
    |> to({user.name, user.email})
    |> from({sender, "no-reply@#{domain}"})
    |> subject(subject)
    |> render_body("welcome.html", %{username: user.name})
    |> premail()
    |> deliver()
  end

  def queue({name, email}) do
    start_time = DateTime.utc_now() |> DateTime.add(1, :minute)
    job = %{start_at: start_time, email: email, name: name}

    #  Timeclock.Workers.Mailer.Welcome.enqueue(job, :start)
  end
end
