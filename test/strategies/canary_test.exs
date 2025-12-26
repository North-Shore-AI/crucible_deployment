defmodule CrucibleDeployment.Strategies.CanaryTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Strategies.Canary
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "progresses through traffic percentages" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "deploy-123"} end)
    |> expect(:set_traffic_weight, fn "deploy-123", 0.1 -> :ok end)
    |> expect(:health_check, fn "deploy-123" -> {:ok, TestSupport.healthy_status()} end)
    |> expect(:set_traffic_weight, fn "deploy-123", 0.3 -> :ok end)

    deployment = TestSupport.build_deployment(:canary)
    {:ok, state} = Canary.init(deployment, %{target_module: Mock})

    assert {:continue, state} = Canary.step(state)
    assert state.current_percent == 10

    assert {:continue, state} = Canary.step(state)
    assert state.current_percent == 30
  end

  test "rolls back on unhealthy status" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "deploy-123"} end)
    |> expect(:set_traffic_weight, fn "deploy-123", 0.1 -> :ok end)
    |> expect(:health_check, fn "deploy-123" -> {:ok, TestSupport.unhealthy_status()} end)

    deployment = TestSupport.build_deployment(:canary)
    {:ok, state} = Canary.init(deployment, %{target_module: Mock})

    assert {:continue, state} = Canary.step(state)
    assert {:rollback, :health_threshold_exceeded} = Canary.step(state)
  end

  test "rollback terminates new deployment and restores old" do
    Mock
    |> expect(:terminate, fn "new" -> :ok end)
    |> expect(:set_traffic_weight, fn "old", 1.0 -> :ok end)

    deployment = TestSupport.build_deployment(:canary)
    {:ok, state} = Canary.init(deployment, %{target_module: Mock, old_deployment_id: "old"})

    state = %{state | new_deployment_id: "new"}
    assert :ok = Canary.rollback(state)
  end
end
