defmodule CrucibleDeployment.Health.Monitor do
  @moduledoc """
  Continuous health monitoring with auto-rollback signals.
  """

  use GenServer

  defstruct [
    :deployment_id,
    :target_module,
    :strategy_pid,
    :check_interval,
    :thresholds,
    :rate_limit_ms,
    :last_check_at
  ]

  @doc """
  Start a health monitor process.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  @impl true
  def init(opts) do
    state = %__MODULE__{
      deployment_id: opts[:deployment_id],
      target_module: opts[:target_module],
      strategy_pid: opts[:strategy_pid],
      check_interval: opts[:check_interval] || :timer.seconds(30),
      thresholds: opts[:thresholds] || %{error_rate: 0.05, p99_latency: 500},
      rate_limit_ms: opts[:rate_limit_ms] || 0,
      last_check_at: nil
    }

    schedule_check(state.check_interval)
    {:ok, state}
  end

  @doc false
  @impl true
  def handle_info(:check_health, state) do
    now = System.monotonic_time(:millisecond)

    if rate_limited?(state, now) do
      schedule_check(rate_limit_delay(state, now))
      {:noreply, state}
    else
      new_state = %{state | last_check_at: now}
      perform_health_check(new_state)
      schedule_check(new_state.check_interval)
      {:noreply, new_state}
    end
  end

  defp schedule_check(interval), do: Process.send_after(self(), :check_health, interval)

  defp exceeds_thresholds?(health, thresholds) do
    health.error_rate > thresholds.error_rate or
      health.latency_p99 > thresholds.p99_latency
  end

  defp emit_telemetry(deployment_id, health) do
    :telemetry.execute(
      [:crucible_deployment, :health_check],
      %{
        latency_p50: health.latency_p50,
        latency_p99: health.latency_p99,
        error_rate: health.error_rate
      },
      %{deployment_id: deployment_id, status: health.status}
    )
  end

  defp perform_health_check(state) do
    case state.target_module.health_check(state.deployment_id) do
      {:ok, health} ->
        if exceeds_thresholds?(health, state.thresholds) do
          send(state.strategy_pid, {:health_alert, :threshold_exceeded, health})
        end

        emit_telemetry(state.deployment_id, health)

      {:error, reason} ->
        send(state.strategy_pid, {:health_alert, :check_failed, reason})
    end
  end

  defp rate_limited?(%{rate_limit_ms: 0}, _now), do: false

  defp rate_limited?(%{last_check_at: nil}, _now), do: false

  defp rate_limited?(%{rate_limit_ms: min_interval, last_check_at: last_check_at}, now) do
    now - last_check_at < min_interval
  end

  defp rate_limit_delay(%{rate_limit_ms: min_interval, last_check_at: last_check_at}, now) do
    min_interval - (now - last_check_at)
  end
end
