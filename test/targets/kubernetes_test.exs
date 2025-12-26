defmodule CrucibleDeployment.Targets.KubernetesTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.Kubernetes
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = Kubernetes.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = Kubernetes.update(deployment_id, %{replicas: 3})
    assert :ok = Kubernetes.terminate(deployment_id)

    assert {:ok, health} = Kubernetes.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = Kubernetes.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = Kubernetes.set_traffic_weight(deployment_id, 0.75)
    assert {:error, :invalid_weight} = Kubernetes.set_traffic_weight(deployment_id, 1.25)
  end
end
