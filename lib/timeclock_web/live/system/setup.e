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
    <div id="setup_wizard" phx-update="stream">
    Select working time preset and adjust settings
    preset rules block
    Setup the rules as you see fit. You can change them later at any time.
    Daily plan
    Number of hours to be worked in a day. Hours worked over or under the plan will be counted into an employees balance.
    8:00
    Paid time rule
    Set a timeframe during which time presence will be counted as paid time.
    You can limit the amount of paid time within a day
    not set
    Required presence
    Set a timeframe where employees' presence is required. All absences will be marked as missing time.
    Enable lunch break
    Employees need to clock in and out of their lunch breaks. Set a duration the employees time will be counted as lunch break.
     8:00
     </div>
    """
  end
end
