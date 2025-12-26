defmodule CrucibleDeployment.Targets.NoopTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.Noop
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = Noop.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = Noop.update(deployment_id, %{note: "noop"})
    assert :ok = Noop.terminate(deployment_id)

    assert {:ok, health} = Noop.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = Noop.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = Noop.set_traffic_weight(deployment_id, 0.0)
    assert {:error, :invalid_weight} = Noop.set_traffic_weight(deployment_id, 2.5)
  end
end
