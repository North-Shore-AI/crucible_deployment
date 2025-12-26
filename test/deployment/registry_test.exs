defmodule CrucibleDeployment.Deployment.RegistryTest do
  use ExUnit.Case, async: false

  alias CrucibleDeployment.Deployment.Registry
  alias CrucibleDeployment.TestSupport

  setup do
    unless Process.whereis(Registry) do
      start_supervised!(Registry)
    end

    :ok
  end

  test "registers and lists deployments" do
    parent = self()

    pid =
      spawn(fn ->
        deployment = TestSupport.build_deployment(:replace, :noop)
        :ok = Registry.register(deployment)
        send(parent, {:registered, deployment})
        Process.sleep(:infinity)
      end)

    assert_receive {:registered, deployment}

    assert {:ok, ^deployment} = Registry.get(deployment.id)
    assert deployment in Registry.list()

    Process.exit(pid, :kill)
  end

  test "returns not_found when missing" do
    assert {:error, :not_found} = Registry.get("missing")
  end
end
