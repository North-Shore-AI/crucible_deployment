defmodule CrucibleDeployment.Targets.OllamaTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Targets.Ollama
  alias CrucibleDeployment.TestSupport.TargetAssertions

  test "supports basic target operations" do
    assert {:ok, deployment_id} = Ollama.deploy(%{model_name: "llama", config: %{}})
    assert is_binary(deployment_id)

    assert :ok = Ollama.update(deployment_id, %{threads: 4})
    assert :ok = Ollama.terminate(deployment_id)

    assert {:ok, health} = Ollama.health_check(deployment_id)
    TargetAssertions.assert_health_status(health)

    assert {:ok, metrics} = Ollama.get_metrics(deployment_id)
    assert is_map(metrics)

    assert :ok = Ollama.set_traffic_weight(deployment_id, 0.2)
    assert {:error, :invalid_weight} = Ollama.set_traffic_weight(deployment_id, -0.1)
  end
end
