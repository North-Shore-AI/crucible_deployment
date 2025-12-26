defmodule CrucibleDeployment.Strategies.BlueGreenTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Strategies.BlueGreen
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "deploys new version and switches traffic" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "green"} end)
    |> expect(:set_traffic_weight, fn "green", +0.0 -> :ok end)
    |> expect(:set_traffic_weight, fn "green", 1.0 -> :ok end)
    |> expect(:set_traffic_weight, fn "blue", +0.0 -> :ok end)
    |> expect(:terminate, fn "blue" -> :ok end)

    deployment = TestSupport.build_deployment(:blue_green)
    {:ok, state} = BlueGreen.init(deployment, %{target_module: Mock, old_deployment_id: "blue"})

    assert {:continue, state} = BlueGreen.step(state)
    assert state.phase == :switching
    assert state.new_deployment_id == "green"

    assert {:complete, result} = BlueGreen.step(state)
    assert result.status == :completed
    assert result.deployment_id == "green"
  end

  test "rolls back by terminating new deployment" do
    Mock
    |> expect(:terminate, fn "green" -> :ok end)
    |> expect(:set_traffic_weight, fn "blue", 1.0 -> :ok end)

    deployment = TestSupport.build_deployment(:blue_green)
    {:ok, state} = BlueGreen.init(deployment, %{target_module: Mock, old_deployment_id: "blue"})

    state = %{state | new_deployment_id: "green"}
    assert :ok = BlueGreen.rollback(state)
  end
end
