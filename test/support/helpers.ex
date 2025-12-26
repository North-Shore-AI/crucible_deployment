defmodule CrucibleDeployment.TestSupport do
  @moduledoc false

  alias CrucibleDeployment.Deployment

  def build_deployment(strategy \\ :replace, target \\ :noop) do
    %Deployment{
      id: "deploy-#{strategy}-#{target}",
      model_version_id: "model-version-1",
      model_name: "test-model",
      target: target,
      strategy: strategy,
      state: :pending,
      config: %{},
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      metrics: %{}
    }
  end

  def healthy_status do
    %{
      status: :healthy,
      latency_p50: 25.0,
      latency_p99: 120.0,
      error_rate: 0.0,
      requests_per_second: 42.0
    }
  end

  def degraded_status do
    %{
      status: :degraded,
      latency_p50: 90.0,
      latency_p99: 400.0,
      error_rate: 0.02,
      requests_per_second: 10.0
    }
  end

  def unhealthy_status do
    %{
      status: :unhealthy,
      latency_p50: 200.0,
      latency_p99: 900.0,
      error_rate: 0.2,
      requests_per_second: 1.0
    }
  end
end
