defmodule TimeclockWeb.SetupLive do
  use TimeclockWeb, :live_view

  def mount(params, _session, socket) do

    socket =
      if connected?(socket) do
        socket
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="setup_wizard" phx-update="stream">
    <h1>Welcome To #{@site}</h1>
    <div>
    We need to setup some rules for your company.
    <br/>
    As soon as your employees start clocking in and out, you will see their time get calculated by the rules you select now.
    <br/>
    And don’t worry, you can change the settings at any time and #{@site} will simply recalculate everyone’s time.
    </div>
    </div>
    """
  end
end
