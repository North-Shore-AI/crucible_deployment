defmodule CrucibleDeployment.Deployment.StateMachine do
  @moduledoc """
  Deployment lifecycle state machine with strategy orchestration.
  """

  use GenServer

  alias CrucibleDeployment.Config
  alias CrucibleDeployment.Deployment.Registry
  alias CrucibleDeployment.Health.Monitor

  defstruct [
    :deployment,
    :strategy_module,
    :strategy_state,
    :target_module,
    :monitor_pid,
    :check_interval,
    :rate_limit_ms,
    :auto_start,
    :step_interval,
    :task_supervisor,
    :step_timeout
  ]

  @doc """
  Start a deployment state machine.
  """
  @spec start_link(CrucibleDeployment.Deployment.t(), keyword()) :: GenServer.on_start()
  def start_link(deployment, opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, {deployment, opts})
  end

  @spec start_link([CrucibleDeployment.Deployment.t() | keyword()]) :: GenServer.on_start()
  def start_link([deployment, opts]) do
    start_link(deployment, opts)
  end

  @doc """
  Trigger a single step in the state machine.
  """
  @spec tick(pid()) :: :ok
  def tick(pid) do
    GenServer.call(pid, :tick)
  end

  @doc """
  Fetch the current state machine status.
  """
  @spec status(pid()) :: map()
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc """
  Force a promotion to 100% traffic.
  """
  @spec promote(pid()) :: :ok | {:error, term()}
  def promote(pid) do
    GenServer.call(pid, :promote)
  end

  @doc """
  Trigger a rollback for the deployment.
  """
  @spec rollback(pid()) :: :ok | {:error, term()}
  def rollback(pid) do
    GenServer.call(pid, :rollback)
  end

  @doc """
  Terminate the deployment and stop the state machine.
  """
  @spec terminate(pid()) :: :ok | {:error, term()}
  def terminate(pid) do
    GenServer.call(pid, :terminate)
  end

  @doc false
  @impl true
  def init({deployment, opts}) do
    with {:ok, strategy_module} <- resolve_strategy_module(deployment, opts),
         {:ok, target_module} <- resolve_target_module(deployment, opts),
         {:ok, strategy_state} <-
           strategy_module.init(
             deployment,
             Map.put(opts[:strategy_opts] || %{}, :target_module, target_module)
           ) do
      deployment = update_deployment_struct(deployment, :deploying)

      state = %__MODULE__{
        deployment: deployment,
        strategy_module: strategy_module,
        strategy_state: strategy_state,
        target_module: target_module,
        monitor_pid: nil,
        check_interval: opts[:check_interval] || :timer.seconds(30),
        rate_limit_ms: opts[:rate_limit_ms] || 0,
        auto_start: Keyword.get(opts, :auto_start, true),
        step_interval: opts[:step_interval] || 0,
        task_supervisor: opts[:task_supervisor] || CrucibleDeployment.TaskSupervisor,
        step_timeout: opts[:step_timeout] || :timer.seconds(30)
      }

      :ok = Registry.register(state.deployment)

      if state.auto_start do
        Process.send_after(self(), :step, state.step_interval)
      end

      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc false
  @impl true
  def handle_call(:tick, _from, state) do
    {_, new_state} = do_step(state, false)
    {:reply, :ok, new_state}
  end

  def handle_call(:status, _from, state) do
    {:reply, %{state: state.deployment.state, deployment: state.deployment}, state}
  end

  def handle_call(:promote, _from, state) do
    new_state = promote_deployment(state)
    {:reply, :ok, new_state}
  end

  def handle_call(:rollback, _from, state) do
    state.strategy_module.rollback(state.strategy_state)
    new_state = update_deployment(state, :rolling_back)
    emit_telemetry(:rollback, new_state.deployment)
    {:reply, :ok, new_state}
  end

  def handle_call(:terminate, _from, state) do
    target_id = target_deployment_id(state) || state.deployment.id
    state.target_module.terminate(target_id)
    new_state = update_deployment(state, :terminated)
    emit_telemetry(:terminate, new_state.deployment)
    {:stop, :normal, :ok, new_state}
  end

  @doc false
  @impl true
  def handle_info(:step, state) do
    {_, new_state} = do_step(state, true)

    if new_state.auto_start and
         new_state.deployment.state not in [:active, :rolling_back, :terminated] do
      Process.send_after(self(), :step, next_interval(new_state))
    end

    {:noreply, new_state}
  end

  def handle_info({:health_alert, reason, details}, state) do
    state.strategy_module.rollback(state.strategy_state)

    updated_state =
      update_deployment(state, :rolling_back)
      |> update_metrics(%{health_alert: {reason, details}})

    emit_telemetry(:rollback, updated_state.deployment)
    {:noreply, updated_state}
  end

  defp do_step(state, use_task_supervisor) do
    result = execute_step(state, use_task_supervisor)

    case result do
      {:continue, strategy_state} ->
        new_state =
          state
          |> Map.put(:strategy_state, strategy_state)
          |> maybe_start_monitor()
          |> update_deployment(deploy_state_for(state.strategy_module))
          |> update_target_id(strategy_state)

        {:continue, new_state}

      {:complete, result_map} ->
        new_state =
          state
          |> Map.put(:strategy_state, state.strategy_state)
          |> update_deployment(:active)
          |> update_metrics(result_map.metrics)
          |> update_target_id(result_map)

        emit_telemetry(:promote, new_state.deployment)
        {:complete, new_state}

      {:rollback, reason} ->
        state.strategy_module.rollback(state.strategy_state)

        new_state =
          state
          |> update_deployment(:rolling_back)
          |> update_metrics(%{rollback_reason: reason})

        emit_telemetry(:rollback, new_state.deployment)
        {:rollback, new_state}
    end
  end

  # Dialyzer infers Task.ref as concrete reference() instead of opaque Task.ref().
  # This is a known limitation when using Task.Supervisor.async_nolink/2 with Task.yield/2.
  # See: https://github.com/elixir-lang/elixir/issues/6426
  @dialyzer {:no_opaque, execute_step: 2}
  defp execute_step(state, use_task_supervisor) do
    if use_task_supervisor and task_supervisor_available?(state.task_supervisor) do
      task =
        Task.Supervisor.async_nolink(state.task_supervisor, fn ->
          state.strategy_module.step(state.strategy_state)
        end)

      case Task.yield(task, state.step_timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        {:exit, reason} -> {:rollback, reason}
        nil -> {:rollback, :step_timeout}
      end
    else
      state.strategy_module.step(state.strategy_state)
    end
  end

  defp task_supervisor_available?(nil), do: false

  defp task_supervisor_available?(name) do
    match?(pid when is_pid(pid), Process.whereis(name))
  end

  defp maybe_start_monitor(%{monitor_pid: nil} = state) do
    deployment_id = target_deployment_id(state) || target_id_from_state(state.strategy_state)

    if is_binary(deployment_id) and task_supervisor_available?(state.task_supervisor) do
      {:ok, monitor_pid} =
        Monitor.start_link(
          deployment_id: deployment_id,
          target_module: state.target_module,
          strategy_pid: self(),
          check_interval: state.check_interval,
          rate_limit_ms: state.rate_limit_ms
        )

      %{state | monitor_pid: monitor_pid}
    else
      state
    end
  end

  defp maybe_start_monitor(state), do: state

  defp resolve_strategy_module(deployment, opts) do
    case opts[:strategy_module] do
      nil -> Config.strategy_module(deployment.strategy)
      module -> {:ok, module}
    end
  end

  defp resolve_target_module(deployment, opts) do
    case opts[:target_module] do
      nil -> Config.target_module(deployment.target)
      module -> {:ok, module}
    end
  end

  defp deploy_state_for(CrucibleDeployment.Strategies.Canary), do: :canary
  defp deploy_state_for(_module), do: :deploying

  defp update_deployment(state, new_state) do
    deployment = %{state.deployment | state: new_state, updated_at: DateTime.utc_now()}
    Registry.update(deployment)
    %{state | deployment: deployment}
  end

  defp update_deployment_struct(deployment, new_state) do
    %{deployment | state: new_state, updated_at: DateTime.utc_now()}
  end

  defp update_metrics(state, metrics) when is_map(metrics) do
    deployment = %{state.deployment | metrics: Map.merge(state.deployment.metrics, metrics)}
    Registry.update(deployment)
    %{state | deployment: deployment}
  end

  defp update_metrics(state, _metrics), do: state

  defp update_target_id(state, result_or_state) do
    case target_id_from_state(result_or_state) do
      nil ->
        state

      target_id ->
        deployment = %{
          state.deployment
          | config: Map.put(state.deployment.config, :target_deployment_id, target_id)
        }

        Registry.update(deployment)
        %{state | deployment: deployment}
    end
  end

  defp target_id_from_state(%{deployment_id: deployment_id}) when is_binary(deployment_id),
    do: deployment_id

  defp target_id_from_state(%{new_deployment_id: deployment_id}) when is_binary(deployment_id),
    do: deployment_id

  defp target_id_from_state(_), do: nil

  defp target_deployment_id(state) do
    Map.get(state.deployment.config, :target_deployment_id)
  end

  defp promote_deployment(state) do
    target_id = target_deployment_id(state) || state.deployment.id

    state.target_module.set_traffic_weight(target_id, 1.0)

    if old_id = Map.get(state.strategy_state, :old_deployment_id) do
      state.target_module.terminate(old_id)
    end

    updated_state = update_deployment(state, :active)
    emit_telemetry(:promote, updated_state.deployment)
    updated_state
  end

  defp emit_telemetry(event, deployment) do
    :telemetry.execute(
      [:crucible_deployment, event],
      %{count: 1},
      %{deployment_id: deployment.id, target: deployment.target, strategy: deployment.strategy}
    )
  end

  defp next_interval(state) do
    if Map.has_key?(state.strategy_state, :evaluation_period) do
      Map.get(state.strategy_state, :evaluation_period)
    else
      state.step_interval
    end
  end
end
