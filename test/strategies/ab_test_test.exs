defmodule CrucibleDeployment.Strategies.ABTestTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Strategies.ABTest
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "deploys and evaluates with equal split" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "new"} end)
    |> expect(:set_traffic_weight, fn "new", 0.5 -> :ok end)
    |> expect(:set_traffic_weight, fn "old", 0.5 -> :ok end)
    |> expect(:health_check, fn "new" -> {:ok, TestSupport.healthy_status()} end)
    |> expect(:set_traffic_weight, fn "new", 1.0 -> :ok end)
    |> expect(:terminate, fn "old" -> :ok end)

    deployment = TestSupport.build_deployment(:ab_test)

    {:ok, state} =
      ABTest.init(deployment, %{
        target_module: Mock,
        old_deployment_id: "old",
        evaluation_period: 0
      })

    assert {:continue, state} = ABTest.step(state)
    assert state.new_deployment_id == "new"

    assert {:complete, result} = ABTest.step(state)
    assert result.status == :completed
    assert result.deployment_id == "new"
  end

  test "rolls back on unhealthy status" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "new"} end)
    |> expect(:set_traffic_weight, fn "new", 0.5 -> :ok end)
    |> expect(:set_traffic_weight, fn "old", 0.5 -> :ok end)
    |> expect(:health_check, fn "new" -> {:ok, TestSupport.unhealthy_status()} end)

    deployment = TestSupport.build_deployment(:ab_test)

    {:ok, state} =
      ABTest.init(deployment, %{
        target_module: Mock,
        old_deployment_id: "old",
        evaluation_period: 0
      })

    assert {:continue, state} = ABTest.step(state)
    assert {:rollback, :health_threshold_exceeded} = ABTest.step(state)
  end
end
