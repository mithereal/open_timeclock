defmodule Timeclock.Types.Address do
  @moduledoc """
  Hardened embedded resource representing a physical or mailing address.
  """
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    attribute :street, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 255, trim?: true
    end

    attribute :city, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :state, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :postal_code, :string do
      public? true
      allow_nil? false
      constraints min_length: 3, max_length: 20, trim?: true, match: ~r/^[A-Za-z0-9\s\-]+$/
    end

    attribute :country, :string do
      public? true
      allow_nil? false
      default "US"
      constraints min_length: 2, max_length: 2, trim?: true, match: ~r/^[A-Z]{2}$/
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:street, :city, :state, :postal_code, :country]
    end

    update :update do
      primary? true
      accept [:street, :city, :state, :postal_code, :country]
    end
  end
end
