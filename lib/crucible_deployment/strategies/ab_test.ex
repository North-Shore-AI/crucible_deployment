defmodule CrucibleDeployment.Strategies.ABTest do
  @moduledoc """
  A/B test rollout with an evaluation period and 50/50 traffic split.
  """

  @behaviour CrucibleDeployment.Strategies.Strategy

  alias CrucibleDeployment.Config
  alias CrucibleDeployment.Health.Rollback

  defstruct [
    :deployment,
    :target_module,
    :old_deployment_id,
    :new_deployment_id,
    :evaluation_period,
    :rollback_threshold,
    :started_at
  ]

  @type t :: %__MODULE__{
          deployment: CrucibleDeployment.Deployment.t(),
          target_module: module(),
          old_deployment_id: String.t() | nil,
          new_deployment_id: String.t() | nil,
          evaluation_period: non_neg_integer(),
          rollback_threshold: map(),
          started_at: non_neg_integer() | nil
        }

  @default_evaluation_period :timer.minutes(10)
  @default_rollback_threshold %{error_rate: 0.05, p99_latency: 500}

  @doc """
  Initialize A/B test strategy state.
  """
  @impl true
  @spec init(CrucibleDeployment.Deployment.t(), map()) :: {:ok, t()} | {:error, term()}
  def init(deployment, opts) do
    with {:ok, target_module} <- resolve_target_module(deployment, opts) do
      state = %__MODULE__{
        deployment: deployment,
        target_module: target_module,
        old_deployment_id: opts[:old_deployment_id],
        new_deployment_id: nil,
        evaluation_period: opts[:evaluation_period] || @default_evaluation_period,
        rollback_threshold: opts[:rollback_threshold] || @default_rollback_threshold,
        started_at: nil
      }

      {:ok, state}
    end
  end

  @doc """
  Execute a step of the A/B rollout.
  """
  @impl true
  @spec step(t()) :: {:continue, t()} | {:complete, map()} | {:rollback, term()}
  def step(%__MODULE__{new_deployment_id: nil} = state) do
    config = Map.put(state.deployment.config, :model_name, state.deployment.model_name)

    case state.target_module.deploy(config) do
      {:ok, new_id} ->
        state.target_module.set_traffic_weight(new_id, 0.5)

        if state.old_deployment_id do
          state.target_module.set_traffic_weight(state.old_deployment_id, 0.5)
        end

        {:continue, %{state | new_deployment_id: new_id, started_at: now_ms()}}

      {:error, reason} ->
        {:rollback, reason}
    end
  end

  def step(state) do
    if evaluation_pending?(state) do
      {:continue, state}
    else
      finalize_evaluation(state)
    end
  end

  @doc """
  Roll back an A/B deployment by terminating the new deployment.
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

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp evaluation_pending?(state) do
    now_ms() - state.started_at < state.evaluation_period
  end

  defp finalize_evaluation(state) do
    with {:ok, health} <- state.target_module.health_check(state.new_deployment_id),
         :ok <- Rollback.evaluate(health, state.rollback_threshold) do
      promote_new(state)
    else
      _ -> {:rollback, :health_threshold_exceeded}
    end
  end

  defp promote_new(state) do
    state.target_module.set_traffic_weight(state.new_deployment_id, 1.0)

    if state.old_deployment_id do
      state.target_module.terminate(state.old_deployment_id)
    end

    {:complete, %{status: :completed, deployment_id: state.new_deployment_id, metrics: %{}}}
  end
end
