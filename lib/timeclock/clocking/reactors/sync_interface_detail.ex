defmodule Timeclock.Clocking.Reactors.SyncInterfaceDetail do
  use Ash.Reactor
  require Logger
  import Ecto.Query

  input :record

  step :enforce_single_default do
    argument :detail, input(:record)

    run fn
      %{detail: %Timeclock.Clocking.InterfaceDetail{id: id, is_default: true} = detail},
      _context ->
        # Demote any other default button atomically so only one default kiosk button exists
        from(d in Timeclock.Clocking.InterfaceDetail,
          where: d.id != ^id and d.is_default == true
        )
        |> Timeclock.Repo.update_all(set: [is_default: false])

        {:ok, detail}

      %{detail: %Timeclock.Clocking.InterfaceDetail{} = detail}, _context ->
        {:ok, detail}

      _invalid, _context ->
        {:error, :invalid_interface_detail}
    end
  end

  step :run_lua_kiosk_ui_hooks do
    argument :detail, result(:enforce_single_default)

    run fn %{detail: detail}, _context ->
      # Hook point: notify Athanor / Lua kiosk UI plugins of button layout change
      {:ok, detail}
    end
  end

  step :broadcast_kiosk_layout_updated do
    argument :detail, result(:run_lua_kiosk_ui_hooks)

    run fn %{detail: detail}, _context ->
      case Phoenix.PubSub.broadcast(
             Timeclock.PubSub,
             "kiosk:interface_details",
             {:interface_detail_updated, detail.id, detail.button_index}
           ) do
        :ok ->
          {:ok, detail}

        {:error, reason} ->
          Logger.warning("Failed to broadcast interface detail #{detail.id}: #{inspect(reason)}")
          {:ok, detail}
      end
    end
  end

  return :broadcast_kiosk_layout_updated
end
