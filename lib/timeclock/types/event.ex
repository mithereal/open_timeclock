defmodule Timeclock.Type.Event do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :value, :integer do
      public? true
    end
  end

  validations do
    validate present([:name, :value]), on: [:create, :update]
    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
