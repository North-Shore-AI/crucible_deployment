defmodule CrucibleDeployment.Strategies.ReplaceTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Strategies.Replace
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "deploys and completes" do
    Mock
    |> expect(:deploy, fn _ -> {:ok, "new-deploy"} end)
    |> expect(:terminate, fn "old-deploy" -> :ok end)

    deployment = TestSupport.build_deployment(:replace)

    {:ok, state} =
      Replace.init(deployment, %{target_module: Mock, old_deployment_id: "old-deploy"})

    assert {:complete, result} = Replace.step(state)
    assert result.status == :completed
    assert result.deployment_id == "new-deploy"
  end

  test "rolls back on deploy error" do
    Mock
    |> expect(:deploy, fn _ -> {:error, :boom} end)

    deployment = TestSupport.build_deployment(:replace)
    {:ok, state} = Replace.init(deployment, %{target_module: Mock})

    assert {:rollback, :boom} = Replace.step(state)
  end

  test "rollback terminates new deployment" do
    Mock
    |> expect(:terminate, fn "new-deploy" -> :ok end)

    deployment = TestSupport.build_deployment(:replace)
    {:ok, state} = Replace.init(deployment, %{target_module: Mock})

    state = %{state | new_deployment_id: "new-deploy"}
    assert :ok = Replace.rollback(state)
  end
end
