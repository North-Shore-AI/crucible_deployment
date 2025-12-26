defmodule CrucibleDeploymentTest do
  use ExUnit.Case, async: false

  import Mox

  alias CrucibleDeployment.Converters.Mock, as: ConverterMock
  alias CrucibleDeployment.Targets.Mock
  alias CrucibleDeployment.TestSupport

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    unless Process.whereis(CrucibleDeployment.Supervisor) do
      start_supervised!(CrucibleDeployment.Application)
    end

    :ok
  end

  test "deploy registers and can be retrieved" do
    {:ok, deployment} =
      CrucibleDeployment.deploy(%{
        model_name: "demo-model",
        target: :noop,
        strategy: :replace,
        auto_start: false
      })

    assert {:ok, fetched} = CrucibleDeployment.get_deployment(deployment.id)
    assert fetched.id == deployment.id

    assert Enum.any?(CrucibleDeployment.list_deployments(), fn item ->
             item.id == deployment.id
           end)
  end

  test "convert uses configured converter" do
    Application.put_env(:crucible_deployment, :converters, %{mock: ConverterMock})

    ConverterMock
    |> expect(:convert, fn "src", :mock, _opts -> {:ok, "out"} end)

    assert {:ok, "out"} = CrucibleDeployment.convert("src", :mock, output_path: "out")
  end

  test "get_status returns health and metrics" do
    Application.put_env(:crucible_deployment, :targets, %{noop: Mock})

    Mock
    |> expect(:health_check, fn _ -> {:ok, TestSupport.healthy_status()} end)
    |> expect(:get_metrics, fn _ -> {:ok, %{requests: 5}} end)

    {:ok, deployment} =
      CrucibleDeployment.deploy(%{
        model_name: "demo-model",
        target: :noop,
        strategy: :replace,
        auto_start: false
      })

    assert {:ok, status} = CrucibleDeployment.get_status(deployment)
    assert status.health.status == :healthy
    assert status.metrics.requests == 5
  end

  test "missing deployment returns not_found" do
    assert {:error, :not_found} = CrucibleDeployment.get_status("missing")
    assert {:error, :not_found} = CrucibleDeployment.get_deployment("missing")
    assert {:error, :not_found} = CrucibleDeployment.promote("missing")
    assert {:error, :not_found} = CrucibleDeployment.rollback("missing")
    assert {:error, :not_found} = CrucibleDeployment.terminate("missing")
  end
end
