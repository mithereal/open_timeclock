defmodule Timeclock.Approvals.AdditionalData do
  @moduledoc """
  Hardened embedded payload for approval request parameters and reviewer notes.
  """
  use Ash.Resource,
    data_layer: :embedded,
    embed_nil_values?: false

  attributes do
    uuid_primary_key :id

    attribute :integer_value, :integer do
      public? true
      allow_nil? true
      constraints min: -10_000, max: 50
    end

    attribute :time_value, :time do
      public? true
      allow_nil? true
    end

    attribute :appliers_comment, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 1000, trim?: true
    end

    attribute :approvers_comment, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 1000, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      # Applicants can only set request values and their own comment on creation
      accept [:integer_value, :time_value, :appliers_comment]
    end

    update :update do
      primary? true
      accept [:integer_value, :time_value, :appliers_comment]
    end

    update :add_approver_comment do
      accept [:approvers_comment]
    end
  end
end
