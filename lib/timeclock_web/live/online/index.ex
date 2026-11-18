defmodule TimeclockWeb.OnlineLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "accounts:sessions:#{current_user.id}")

        user_key = to_string(current_user.id)

        TimeclockWeb.Presence.track_user(user_key, %{
          id: user_key,
          email: to_string(current_user.email),
          role: to_string(current_user.role)
        })

        TimeclockWeb.Presence.subscribe()

        presence_list =
          TimeclockWeb.Presence.list_online_users()
          |> Enum.map(fn {key, %{metas: metas}} ->
            build_presence_item(key, metas)
          end)

        stream(socket, :presences, presence_list)
      else
        socket
      end

    {:ok, assign(socket, page_title: "Live Presence Directory")}
  end

  @impl true
  def handle_info({TimeclockWeb.Presence, {:join, {user_key, %{metas: metas}}}}, socket) do
    {:noreply, stream_insert(socket, :presences, build_presence_item(user_key, metas))}
  end

  @impl true
  def handle_info({TimeclockWeb.Presence, {:leave, {user_key, %{metas: metas}}}}, socket) do
    payload = build_presence_item(user_key, metas)

    if metas == [] do
      {:noreply, stream_delete(socket, :presences, payload)}
    else
      {:noreply, stream_insert(socket, :presences, payload)}
    end
  end

  @impl true
  def handle_info({:session_revoked, _subject}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Your session has been revoked.")
     |> redirect(to: ~p"/")}
  end

  defp build_presence_item(user_key, metas) do
    first_meta = List.first(metas) || %{}

    %{
      id: user_key,
      email: Map.get(first_meta, :email, user_key),
      role: Map.get(first_meta, :role, "employee"),
      device_count: length(metas)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-2xl mx-auto space-y-4">
      <div class="border-b pb-3">
        <h1 class="text-2xl font-black tracking-tight text-slate-900">Live Presence Directory</h1>
        <p class="text-xs text-slate-500 mt-0.5">
          Real-time terminal visibility monitoring authenticated user sessions.
        </p>
      </div>

      <ul
        id="online_users"
        phx-update="stream"
        class="divide-y divide-slate-100 bg-white border rounded-xl overflow-hidden shadow-2xs"
      >
        <li
          id="online_users_empty"
          class="hidden only:block p-8 text-center text-xs text-slate-400 font-medium"
        >
          No authenticated profiles currently active in this workspace.
        </li>

        <li
          :for={{dom_id, user} <- @streams.presences}
          id={dom_id}
          class="p-4 flex items-center justify-between hover:bg-slate-50/50 transition"
        >
          <div class="flex items-center gap-3 min-w-0">
            <span class="h-2 w-2 rounded-full bg-emerald-500 animate-pulse shrink-0"></span>
            <span class="font-mono text-sm font-semibold text-slate-800 truncate">
              {user.email}
            </span>
            <span class="px-2 py-0.5 text-[10px] font-mono uppercase rounded bg-indigo-50 text-indigo-700 border border-indigo-200">
              {user.role}
            </span>
          </div>

          <span class="text-xs font-bold font-mono px-2.5 py-0.5 bg-slate-100 border border-slate-200 text-slate-600 rounded-md shrink-0">
            Active Devices: {user.device_count}
          </span>
        </li>
      </ul>
    </div>
    """
  end
end
