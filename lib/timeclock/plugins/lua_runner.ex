defmodule Timeclock.Plugins.LuaRunner do
  @moduledoc """
  Executes admin-uploaded Lua scripts inside a stripped, timeout-bounded `luerl` sandbox.
  """
  require Logger

  @default_timeout_ms 100

  @forbidden_globals [
    ["os"],
    ["io"],
    ["package"],
    ["debug"],
    ["require"],
    ["dofile"],
    ["loadfile"],
    ["load"],
    ["loadstring"]
  ]

  @doc """
  Dispatches `event_name` through all active scripts registered for that hook.
  If zero active plugins exist (or the registry is empty), immediately returns `{:ok, payload}`
  so Reactor pipelines continue with zero overhead.
  """
  def dispatch(event_name, payload, opts \\ []) when is_binary(event_name) and is_map(payload) do
    case fetch_active_scripts(event_name) do
      [] ->
        {:ok, payload}

      scripts ->
        Enum.reduce_while(scripts, {:ok, payload}, fn script, {:ok, acc_payload} ->
          case run_script(script.source_code, acc_payload, Keyword.put(opts, :script_name, script.name)) do
            {:ok, next_payload} when is_map(next_payload) ->
              {:cont, {:ok, Map.merge(acc_payload, next_payload)}}

            {:ok, _other} ->
              {:cont, {:ok, acc_payload}}

            {:error, reason} ->
              Logger.warning("Lua plugin '#{script.name}' rejected '#{event_name}': #{inspect(reason)}")
              {:halt, {:error, {script.name, reason}}}
          end
        end)
    end
  end

  defp fetch_active_scripts(event_name) do
    case Timeclock.Plugins.Script.active_for_hook(event_name) do
      {:ok, scripts} -> scripts
      {:error, _} -> []
    end
  rescue
    _ -> []
  end


  @doc """
  Compiles and dry-runs a Lua script against sample input to verify syntax and sandbox safety
  before saving it to the registry.
  """
  def validate_syntax(source_code) when is_binary(source_code) do
    task =
      Task.async(fn ->
        state = init_sandbox_state()

        case :luerl.load(source_code, state) do
          {:ok, _chunk, _state} -> :ok
          {:error, reason, _state} -> {:error, inspect(reason)}
        end
      end)

    case Task.yield(task, @default_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, :ok} -> :ok
      {:ok, {:error, msg}} -> {:error, msg}
      nil -> {:error, "Lua syntax check timed out"}
    end
  end

  @doc """
  Runs a single Lua script with `payload` exposed as global `context` and host helpers under `tc`.
  A script may return:
    - `{ ok = true, data = { ... } }` -> continues pipeline with merged fields
    - `{ ok = false, error = "reason" }` -> halts pipeline and rejects the Ash action/workflow
  """
  def run_script(source_code, payload, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    script_name = Keyword.get(opts, :script_name, "inline")

    task =
      Task.async(fn ->
        try do
          state =
            init_sandbox_state()
            |> inject_context(payload)
            |> inject_host_api(script_name)

          case :luerl.do(source_code, state) do
            {:ok, [result | _], _new_state} ->
              interpret_lua_result(result)

            {:ok, [], _new_state} ->
              {:ok, payload}

            {:error, reason, _new_state} ->
              {:error, {:lua_runtime_error, inspect(reason)}}
          end
        rescue
          e -> {:error, {:lua_exception, Exception.message(e)}}
        end
      end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, {:lua_timeout, "Script '#{script_name}' exceeded #{timeout_ms}ms limit"}}
    end
  end

  defp init_sandbox_state do
    state = :luerl.init()

    Enum.reduce(@forbidden_globals, state, fn path, acc ->
      {:ok, next_state} = :luerl.set_table_keys(path, nil, acc)
      next_state
    end)
  end

  defp inject_context(state, payload) do
    sanitized = sanitize_for_lua(payload)
    {:ok, next_state} = :luerl.set_table_keys(["context"], sanitized, state)
    next_state
  end

  defp inject_host_api(state, script_name) do
    log_fn = fn args, luerl_state ->
      Logger.info("[Lua:#{script_name}] #{inspect(args)}")
      {[], luerl_state}
    end

    now_utc_fn = fn _args, luerl_state ->
      {[DateTime.utc_now() |> DateTime.to_iso8601()], luerl_state}
    end

    {:ok, state} = :luerl.set_table_keys(["tc"], %{}, state)
    {:ok, state} = :luerl.set_table_keys(["tc", "log"], log_fn, state)
    {:ok, state} = :luerl.set_table_keys(["tc", "now_utc"], now_utc_fn, state)
    state
  end

  defp interpret_lua_result(result) when is_list(result) do
    map = lua_table_to_map(result)

    case Map.get(map, "ok") do
      false ->
        {:error, Map.get(map, "error", "rejected_by_lua_plugin")}

      _ ->
        case Map.get(map, "data") do
          data when is_map(data) -> {:ok, data}
          _ -> {:ok, %{}}
        end
    end
  end

  defp interpret_lua_result(_other), do: {:ok, %{}}

  defp sanitize_for_lua(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__, :hashed_password, :assigned_pin, :email_api_key, :email_api_secret, :smtp_password])
    |> sanitize_for_lua()
  end

  defp sanitize_for_lua(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), sanitize_for_lua(v)} end)
  end

  defp sanitize_for_lua(list) when is_list(list), do: Enum.map(list, &sanitize_for_lua/1)
  defp sanitize_for_lua(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp sanitize_for_lua(%Date{} = d), do: Date.to_iso8601(d)
  defp sanitize_for_lua(%Time{} = t), do: Time.to_iso8601(t)
  defp sanitize_for_lua(atom) when is_atom(atom) and not is_boolean(atom) and not is_nil(atom), do: Atom.to_string(atom)
  defp sanitize_for_lua(val), do: val

  defp lua_table_to_map(pairs) when is_list(pairs) do
    Map.new(pairs, fn
      {k, v} when is_list(v) -> {to_string(k), lua_table_to_map(v)}
      {k, v} -> {to_string(k), v}
    end)
  end
end
