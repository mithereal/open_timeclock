defmodule Timeclock.Types.Address do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    attribute :street, :string do
      public? true
    end

    attribute :city, :string do
      public? true
    end

    attribute :state, :string do
      public? true
    end

    attribute :postal_code, :string do
      public? true
    end

    attribute :country, :string do
      public? true
    end
  end

  validations do
    validate present([:street, :city, :state, :postal_code, :country]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
