defmodule CrucibleDeployment.Strategies.Replace do
  @moduledoc """
  Direct replacement rollout strategy.
  """

  @behaviour CrucibleDeployment.Strategies.Strategy

  alias CrucibleDeployment.Config

  defstruct [:deployment, :target_module, :old_deployment_id, :new_deployment_id]

  @type t :: %__MODULE__{
          deployment: CrucibleDeployment.Deployment.t(),
          target_module: module(),
          old_deployment_id: String.t() | nil,
          new_deployment_id: String.t() | nil
        }

  @doc """
  Initialize replace strategy state.
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
  Execute the replace rollout in a single step.
  """
  @impl true
  @spec step(t()) :: {:continue, t()} | {:complete, map()} | {:rollback, term()}
  def step(%__MODULE__{new_deployment_id: nil} = state) do
    config = Map.put(state.deployment.config, :model_name, state.deployment.model_name)

    case state.target_module.deploy(config) do
      {:ok, new_id} ->
        if state.old_deployment_id do
          state.target_module.terminate(state.old_deployment_id)
        end

        {:complete, %{status: :completed, deployment_id: new_id, metrics: %{}}}

      {:error, reason} ->
        {:rollback, reason}
    end
  end

  def step(%__MODULE__{new_deployment_id: new_id}) do
    {:complete, %{status: :completed, deployment_id: new_id, metrics: %{}}}
  end

  @doc """
  Roll back a replace deployment by terminating the new deployment.
  """
  @impl true
  @spec rollback(t()) :: :ok | {:error, term()}
  def rollback(state) do
    if state.new_deployment_id do
      state.target_module.terminate(state.new_deployment_id)
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
