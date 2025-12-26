defmodule CrucibleDeployment.Targets.VLLMTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.VLLM
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = VLLM.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = VLLM.update(deployment_id, %{replicas: 2})
    assert :ok = VLLM.terminate(deployment_id)

    assert {:ok, health} = VLLM.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = VLLM.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = VLLM.set_traffic_weight(deployment_id, 0.5)
    assert {:error, :invalid_weight} = VLLM.set_traffic_weight(deployment_id, 1.5)
  end
end
