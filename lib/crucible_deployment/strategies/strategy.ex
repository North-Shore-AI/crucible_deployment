defmodule CrucibleDeployment.Strategies.Strategy do
  @moduledoc """
  Behaviour for deployment rollout strategies.
  """

  @type deployment :: CrucibleDeployment.Deployment.t()
  @type state :: term()
  @type result :: %{
          status: :completed | :in_progress | :rolled_back | :failed,
          deployment_id: String.t(),
          metrics: map()
        }

  @callback init(deployment :: deployment(), opts :: map()) :: {:ok, state()} | {:error, term()}
  @callback step(state()) ::
              {:continue, state()} | {:complete, result()} | {:rollback, reason :: term()}
  @callback rollback(state()) :: :ok | {:error, term()}
end
