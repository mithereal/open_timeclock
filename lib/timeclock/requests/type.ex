defmodule Timeclock.Requests.Type do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  @allowed_values [0, 1, 2, 3, 4, 5]

  attributes do
    uuid_primary_key :id

    attribute :request_type, :integer
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "request_types"
    repo Timeclock.Repo
  end

  validations do
    validate present([:request_type]), on: [:create, :update]
    validate one_of(:request_type, @allowed_values), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
