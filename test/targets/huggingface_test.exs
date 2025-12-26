defmodule CrucibleDeployment.Targets.HuggingFaceTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.HuggingFace
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = HuggingFace.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = HuggingFace.update(deployment_id, %{min_replicas: 1})
    assert :ok = HuggingFace.terminate(deployment_id)

    assert {:ok, health} = HuggingFace.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = HuggingFace.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = HuggingFace.set_traffic_weight(deployment_id, 0.9)
    assert {:error, :invalid_weight} = HuggingFace.set_traffic_weight(deployment_id, -0.5)
  end
end
