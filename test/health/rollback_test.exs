defmodule CrucibleDeployment.Health.RollbackTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Health.Rollback
  alias CrucibleDeployment.TestSupport

  test "returns rollback for unhealthy health" do
    thresholds = %{error_rate: 0.05, p99_latency: 500}

    assert {:rollback, :threshold_exceeded} =
             Rollback.evaluate(TestSupport.unhealthy_status(), thresholds)
  end

  test "returns ok for healthy health" do
    thresholds = %{error_rate: 0.05, p99_latency: 500}
    assert :ok = Rollback.evaluate(TestSupport.healthy_status(), thresholds)
  end
end
