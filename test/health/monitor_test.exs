defmodule CrucibleDeployment.Health.MonitorTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Health.Monitor
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "sends alert on threshold exceeded" do
    Mock
    |> expect(:health_check, fn "dep-1" -> {:ok, TestSupport.unhealthy_status()} end)

    {:ok, pid} =
      Monitor.start_link(
        deployment_id: "dep-1",
        target_module: Mock,
        strategy_pid: self(),
        check_interval: 1_000_000,
        rate_limit_ms: 0,
        thresholds: %{error_rate: 0.05, p99_latency: 500}
      )

    Mox.allow(Mock, self(), pid)

    send(pid, :check_health)
    assert_receive {:health_alert, :threshold_exceeded, _health}
  end

  test "sends alert on check failure" do
    Mock
    |> expect(:health_check, fn "dep-2" -> {:error, :timeout} end)

    {:ok, pid} =
      Monitor.start_link(
        deployment_id: "dep-2",
        target_module: Mock,
        strategy_pid: self(),
        check_interval: 1_000_000,
        rate_limit_ms: 0
      )

    Mox.allow(Mock, self(), pid)

    send(pid, :check_health)
    assert_receive {:health_alert, :check_failed, :timeout}
  end
end
