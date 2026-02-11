defmodule Timeclock.Types.Icon do
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :uri, :string do
      public? true
    end
  end

  identities do
    identity :unique_id, [:id]
  end

  validations do
    validate present([:name, :uri]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
