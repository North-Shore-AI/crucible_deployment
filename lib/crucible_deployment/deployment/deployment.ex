defmodule CrucibleDeployment.Deployment do
  @moduledoc """
  Represents a model deployment and its lifecycle metadata.
  """

  @type state ::
          :pending
          | :deploying
          | :canary
          | :promoting
          | :active
          | :rolling_back
          | :terminated

  @type t :: %__MODULE__{
          id: String.t(),
          model_version_id: String.t() | nil,
          model_name: String.t(),
          target: atom(),
          strategy: atom(),
          state: state(),
          config: map(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          metrics: map()
        }

  defstruct [
    :id,
    :model_version_id,
    :model_name,
    :target,
    :strategy,
    state: :pending,
    config: %{},
    created_at: nil,
    updated_at: nil,
    metrics: %{}
  ]
end
