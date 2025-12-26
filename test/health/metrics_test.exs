defmodule CrucibleDeployment.Health.MetricsTest do
  use ExUnit.Case, async: true

  import Mox

  alias CrucibleDeployment.Health.Metrics
  alias CrucibleDeployment.Targets.Mock

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "collects metrics from target" do
    Mock
    |> expect(:get_metrics, fn "dep-1" -> {:ok, %{requests: 10}} end)

    assert {:ok, %{requests: 10}} = Metrics.collect(Mock, "dep-1")
  end
end
