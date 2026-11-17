defmodule Timeclock.TimeTracking.Reactors.ValidateGeolocation do
  use Ash.Reactor

  input :geolocation
  input :target_location, default: nil
  input :max_radius_meters, default: nil

  step :verify_coordinate_bounds do
    argument :geo, input(:geolocation)

    run fn
      %{geo: %Timeclock.TimeTracking.Geolocation{latitude: lat, longitude: lon} = geo}, _context
      when is_number(lat) and is_number(lon) and lat >= -90.0 and lat <= 90.0 and lon >= -180.0 and
             lon <= 180.0 ->
        {:ok, geo}

      _invalid, _context ->
        {:error, :invalid_gps_coordinates}
    end
  end

  step :check_geofence_radius do
    argument :geo, result(:verify_coordinate_bounds)
    argument :target, input(:target_location)
    argument :radius, input(:max_radius_meters)

    run fn
      %{geo: geo, target: nil}, _context ->
        {:ok, %{geolocation: geo, within_geofence?: true, distance_meters: 0.0}}

      %{geo: geo, target: %{latitude: t_lat, longitude: t_lon}, radius: max_r}, _context
      when is_number(t_lat) and is_number(t_lon) and is_number(max_r) ->
        distance = haversine_meters(geo.latitude, geo.longitude, t_lat, t_lon)

        if distance <= max_r do
          {:ok, %{geolocation: geo, within_geofence?: true, distance_meters: distance}}
        else
          {:error, {:outside_geofence, Float.round(distance, 2)}}
        end

      %{geo: geo}, _context ->
        {:ok, %{geolocation: geo, within_geofence?: true, distance_meters: 0.0}}
    end
  end

  step :run_lua_geolocation_hooks do
    argument :check_result, result(:check_geofence_radius)

    run fn %{check_result: res}, _context ->
      # Hook point: invoke Lua geofence/zone plugins ("geolocation.validate")
      {:ok, res}
    end
  end

  return :run_lua_geolocation_hooks

  defp haversine_meters(lat1, lon1, lat2, lon2) do
    r = 6_371_000.0
    rad = :math.pi() / 180.0
    dlat = (lat2 - lat1) * rad
    dlon = (lon2 - lon1) * rad

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1 * rad) * :math.cos(lat2 * rad) *
          :math.sin(dlon / 2) * :math.sin(dlon / 2)

    2 * r * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end
end
