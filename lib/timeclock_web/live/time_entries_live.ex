defmodule TimeclockWeb.TimeEntriesLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "time_entries:#{current_user.id}")
    end

    tasks = Ash.read!(Timeclock.Projects.Task, actor: current_user)

    {:ok,
     socket
     |> assign(
       page_title: "Daily Time Entries",
       scope: :today,
       task_options: Enum.map(tasks, &{&1.name, &1.id}),
       form: build_punch_form(current_user),
       disputing_entry_id: nil,
       dispute_reason: ""
     )
     |> load_entries(current_user, :today)}
  end

  @impl true
  def handle_event("switch_scope", %{"scope" => scope_str}, socket) do
    scope = if scope_str == "all", do: :all, else: :today
    {:noreply, socket |> assign(scope: scope) |> load_entries(socket.assigns.current_user, scope)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save_entry", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Time entry recorded.")
         |> assign(form: build_punch_form(current_user))
         |> load_entries(current_user, socket.assigns.scope)}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("open_dispute", %{"id" => id}, socket) do
    {:noreply, assign(socket, disputing_entry_id: id, dispute_reason: "")}
  end

  @impl true
  def handle_event("cancel_dispute", _params, socket) do
    {:noreply, assign(socket, disputing_entry_id: nil, dispute_reason: "")}
  end

  @impl true
  def handle_event("submit_dispute", %{"id" => id, "reason" => reason}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, entry} <- Ash.get(Timeclock.TimeTracking.TimeEntry, id, actor: current_user),
         {:ok, _disputed} <-
           Ash.update(entry, :dispute, %{dispute_reason: reason}, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Time entry flagged for manager review.")
       |> assign(disputing_entry_id: nil, dispute_reason: "")
       |> load_entries(current_user, socket.assigns.scope)}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to dispute this time entry.")}
    end
  end

  @impl true
  def handle_info({:time_entry_recorded, _id, _direction, _timestamp}, socket) do
    {:noreply, load_entries(socket, socket.assigns.current_user, socket.assigns.scope)}
  end

  defp load_entries(socket, current_user, :today) do
    entries =
      Timeclock.TimeTracking.TimeEntry
      |> Ash.Query.for_read(:today, %{}, actor: current_user)
      |> Ash.Query.load([:task])
      |> Ash.read!(actor: current_user)

    assign(socket,
      entries: entries,
      paired_shifts: pair_chronological_entries(entries),
      total_seconds: total_worked_seconds(entries)
    )
  end

  defp load_entries(socket, current_user, :all) do
    entries =
      Timeclock.TimeTracking.TimeEntry
      |> Ash.Query.filter(user_id == ^current_user.id)
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.load([:task])
      |> Ash.Query.limit(50)
      |> Ash.read!(actor: current_user)

    assign(socket,
      entries: entries,
      paired_shifts: pair_chronological_entries(entries),
      total_seconds: total_worked_seconds(entries)
    )
  end

  defp build_punch_form(current_user) do
    Timeclock.TimeTracking.TimeEntry
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp pair_chronological_entries(entries) do
    entries
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> build_pairs([])
  end

  defp build_pairs([], acc), do: Enum.reverse(acc)

  defp build_pairs([%{direction: :in} = entry_in, %{direction: :out} = entry_out | rest], acc) do
    seconds = max(DateTime.diff(entry_out.timestamp, entry_in.timestamp, :second), 0)

    pair = %{
      started_at: entry_in.timestamp,
      ended_at: entry_out.timestamp,
      duration_seconds: seconds,
      open?: false
    }

    build_pairs(rest, [pair | acc])
  end

  defp build_pairs([%{direction: :in} = open_in | rest], acc) do
    seconds = max(DateTime.diff(DateTime.utc_now(), open_in.timestamp, :second), 0)

    pair = %{
      started_at: open_in.timestamp,
      ended_at: nil,
      duration_seconds: seconds,
      open?: true
    }

    build_pairs(rest, [pair | acc])
  end

  defp build_pairs([_unpaired_out | rest], acc), do: build_pairs(rest, acc)

  defp total_worked_seconds(entries) do
    entries
    |> pair_chronological_entries()
    |> Enum.reduce(0, &(&1.duration_seconds + &2))
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{String.pad_leading(to_string(minutes), 2, "0")}m"
  end

  defp state_badge(:verified), do: "bg-green-100 text-green-800"
  defp state_badge(:disputed), do: "bg-red-100 text-red-800"
  defp state_badge(:voided), do: "bg-gray-100 text-gray-500"
  defp state_badge(_), do: "bg-amber-100 text-amber-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Daily Time Entries & Paired Shifts</h1>
          <p class="text-sm text-gray-500 mt-1">
            Record shift punches, inspect paired in/out intervals, and flag incorrect punches for review.
          </p>
        </div>

        <div class="flex items-center gap-4">
          <div class="px-4 py-2 bg-indigo-50 border border-indigo-200 rounded-xl text-right">
            <span class="block text-[10px] font-bold uppercase text-indigo-600">Total Logged</span>
            <span class="font-mono text-lg font-black text-indigo-900">
              {format_duration(@total_seconds)}
            </span>
          </div>

          <div class="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
            <button
              type="button"
              phx-click="switch_scope"
              phx-value-scope="today"
              class={"px-3 py-1.5 rounded-md transition #{if @scope == :today, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
            >
              Today
            </button>
            <button
              type="button"
              phx-click="switch_scope"
              phx-value-scope="all"
              class={"px-3 py-1.5 rounded-md transition #{if @scope == :all, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
            >
              Recent 50
            </button>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Quick Punch Panel -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit space-y-4">
          <h2 class="text-lg font-bold text-gray-900">Quick Time Entry</h2>
          <.form for={@form} phx-change="validate" phx-submit="save_entry" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Direction</label>
              <.input
                field={@form[:direction]}
                type="select"
                options={[{"Clock In", "in"}, {"Clock Out", "out"}]}
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">
                Project Task (Optional)
              </label>
              <.input
                field={@form[:task_id]}
                type="select"
                options={@task_options}
                prompt="General Shift Time"
                class="w-full text-sm"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg text-sm transition"
            >
              Record Punch Now
            </button>
          </.form>

          <!-- Paired Shift Intervals Summary -->
          <div class="pt-4 border-t space-y-2">
            <h3 class="text-xs font-bold text-gray-500 uppercase tracking-wider">
              Paired Intervals
            </h3>
            <div
              :for={pair <- @paired_shifts}
              class="p-2.5 rounded-lg bg-slate-50 border border-gray-200 flex items-center justify-between text-xs font-mono"
            >
              <div>
                <span>{Calendar.strftime(pair.started_at, "%H:%M")}</span>
                <span>→</span>
                <span>
                  {if pair.ended_at, do: Calendar.strftime(pair.ended_at, "%H:%M"), else: "Active"}
                </span>
              </div>
              <span class={"font-bold #{if pair.open?, do: "text-emerald-600", else: "text-gray-800"}"}>
                {format_duration(pair.duration_seconds)}
              </span>
            </div>
            <p :if={Enum.empty?(@paired_shifts)} class="text-xs text-gray-400 italic">
              No paired shift blocks yet.
            </p>
          </div>
        </div>

        <!-- Raw Time Entries Ledger -->
        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Time Entry Audit Log</h2>
          <div class="overflow-x-auto">
Use code with caution.

Direction	Timestamp (UTC)	Task	State	Actions
	{Calendar.strftime(entry.timestamp, "%Y-%m-%d %H:%M:%S")}	{if entry.task, do: entry.task.name, else: "—"}		
No time entries recorded for this window.

Flag Time Entry for Manager Review





Cancel


Submit Dispute







"""
end
end