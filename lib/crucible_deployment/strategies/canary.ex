defmodule CrucibleDeployment.Strategies.Canary do
  @moduledoc """
  Gradual traffic shift with automatic rollback.

  Default progression: 10% -> 30% -> 50% -> 100%
  Evaluates health at each step before proceeding.
  """

  @behaviour CrucibleDeployment.Strategies.Strategy

  alias CrucibleDeployment.Config
  alias CrucibleDeployment.Health.Rollback

  defstruct [
    :deployment,
    :target_module,
    :current_percent,
    :steps,
    :evaluation_period,
    :rollback_threshold,
    :old_deployment_id,
    :new_deployment_id
  ]

  @type t :: %__MODULE__{
          deployment: CrucibleDeployment.Deployment.t(),
          target_module: module(),
          current_percent: non_neg_integer(),
          steps: [non_neg_integer()],
          evaluation_period: non_neg_integer(),
          rollback_threshold: map(),
          old_deployment_id: String.t() | nil,
          new_deployment_id: String.t() | nil
        }

  @default_steps [10, 30, 50, 100]
  @default_evaluation_period :timer.minutes(5)
  @default_rollback_threshold %{error_rate: 0.05, p99_latency: 500}

  @doc """
  Initialize canary strategy state.
  """
  @impl true
  @spec init(CrucibleDeployment.Deployment.t(), map()) :: {:ok, t()} | {:error, term()}
  def init(deployment, opts) do
    with {:ok, target_module} <- resolve_target_module(deployment, opts) do
      state = %__MODULE__{
        deployment: deployment,
        target_module: target_module,
        current_percent: 0,
        steps: opts[:steps] || @default_steps,
        evaluation_period: opts[:evaluation_period] || @default_evaluation_period,
        rollback_threshold: opts[:rollback_threshold] || @default_rollback_threshold,
        old_deployment_id: opts[:old_deployment_id],
        new_deployment_id: nil
      }

      {:ok, state}
    end
  end

  @doc """
  Execute a canary rollout step.
  """
  @impl true
  @spec step(t()) :: {:continue, t()} | {:complete, map()} | {:rollback, term()}
  def step(%__MODULE__{current_percent: 0} = state) do
    config = Map.put(state.deployment.config, :model_name, state.deployment.model_name)

    case state.target_module.deploy(config) do
      {:ok, new_id} ->
        next_percent = hd(state.steps)
        state.target_module.set_traffic_weight(new_id, next_percent / 100)

        {:continue, %{state | new_deployment_id: new_id, current_percent: next_percent}}

      {:error, reason} ->
        {:rollback, reason}
    end
  end

  def step(%__MODULE__{current_percent: 100} = state) do
    if state.old_deployment_id do
      state.target_module.terminate(state.old_deployment_id)
    end

    {:complete, %{status: :completed, deployment_id: state.new_deployment_id, metrics: %{}}}
  end

  def step(state) do
    case evaluate_health(state) do
      :healthy ->
        next_percent = next_step(state.steps, state.current_percent)
        state.target_module.set_traffic_weight(state.new_deployment_id, next_percent / 100)

        {:continue, %{state | current_percent: next_percent}}

      :degraded ->
        {:continue, state}

      :unhealthy ->
        {:rollback, :health_threshold_exceeded}
    end
  end

  @doc """
  Roll back a canary deployment by terminating the new deployment.
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

  defp evaluate_health(state) do
    with {:ok, health} <- state.target_module.health_check(state.new_deployment_id),
         :ok <- Rollback.evaluate(health, state.rollback_threshold) do
      if health.status == :degraded, do: :degraded, else: :healthy
    else
      {:rollback, _reason} -> :unhealthy
      {:error, _reason} -> :unhealthy
    end
  end

  defp next_step(steps, current_percent) do
    case Enum.find(steps, fn step -> step > current_percent end) do
      nil -> 100
      step -> step
    end
  end
end
