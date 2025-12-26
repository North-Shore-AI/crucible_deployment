defmodule CrucibleDeployment.Strategies.BlueGreen do
  @moduledoc """
  Blue/green deployment strategy with traffic switch.
  """

  @behaviour CrucibleDeployment.Strategies.Strategy

  alias CrucibleDeployment.Config

  defstruct [
    :deployment,
    :target_module,
    :old_deployment_id,
    :new_deployment_id,
    phase: :deploying
  ]

  @type t :: %__MODULE__{
          deployment: CrucibleDeployment.Deployment.t(),
          target_module: module(),
          old_deployment_id: String.t() | nil,
          new_deployment_id: String.t() | nil,
          phase: :deploying | :switching
        }

  @doc """
  Initialize blue/green strategy state.
  """
  @impl true
  @spec init(CrucibleDeployment.Deployment.t(), map()) :: {:ok, t()} | {:error, term()}
  def init(deployment, opts) do
    with {:ok, target_module} <- resolve_target_module(deployment, opts) do
      state = %__MODULE__{
        deployment: deployment,
        target_module: target_module,
        old_deployment_id: opts[:old_deployment_id],
        new_deployment_id: opts[:new_deployment_id]
      }

      {:ok, state}
    end
  end

  @doc """
  Execute a step of the blue/green rollout.
  """
  @impl true
  @spec step(t()) :: {:continue, t()} | {:complete, map()} | {:rollback, term()}
  def step(%__MODULE__{phase: :deploying} = state) do
    config = Map.put(state.deployment.config, :model_name, state.deployment.model_name)

    case state.target_module.deploy(config) do
      {:ok, new_id} ->
        state.target_module.set_traffic_weight(new_id, 0.0)

        {:continue, %{state | new_deployment_id: new_id, phase: :switching}}

      {:error, reason} ->
        {:rollback, reason}
    end
  end

  def step(%__MODULE__{phase: :switching, new_deployment_id: new_id} = state) do
    state.target_module.set_traffic_weight(new_id, 1.0)

    if state.old_deployment_id do
      state.target_module.set_traffic_weight(state.old_deployment_id, 0.0)
      state.target_module.terminate(state.old_deployment_id)
    end

    {:complete, %{status: :completed, deployment_id: new_id, metrics: %{}}}
  end

  @doc """
  Roll back a blue/green deployment by restoring the old deployment.
  """
  @impl true
  @spec rollback(t()) :: :ok | {:error, term()}
  def rollback(state) do
    if state.new_deployment_id do
      state.target_module.terminate(state.new_deployment_id)
    end

    if state.old_deployment_id do
      state.target_module.set_traffic_weight(state.old_deployment_id, 1.0)
    end

    :ok
  end

  defp resolve_target_module(deployment, opts) do
    case opts[:target_module] do
      nil -> Config.target_module(deployment.target)
      module -> {:ok, module}
    end
  end
end
