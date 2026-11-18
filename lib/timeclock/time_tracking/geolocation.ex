defmodule Timeclock.TimeTracking.Geolocation do
  @moduledoc """
  Hardened embedded resource representing WGS-84 GPS coordinates for time entries and locations.
  """
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    uuid_primary_key :id

    attribute :latitude, :float do
      public? true
      allow_nil? false
      constraints min: -90.0, max: 90.0
    end

    attribute :longitude, :float do
      public? true
      allow_nil? false
      constraints min: -180.0, max: 180.0
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:latitude, :longitude]
    end

    update :update do
      primary? true
      accept [:latitude, :longitude]
    end
  end
end
