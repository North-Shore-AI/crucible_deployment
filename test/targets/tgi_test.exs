defmodule CrucibleDeployment.Targets.TGITest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.TGI
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = TGI.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = TGI.update(deployment_id, %{shard_count: 2})
    assert :ok = TGI.terminate(deployment_id)

    assert {:ok, health} = TGI.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = TGI.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = TGI.set_traffic_weight(deployment_id, 1.0)
    assert {:error, :invalid_weight} = TGI.set_traffic_weight(deployment_id, 2.0)
  end
end
