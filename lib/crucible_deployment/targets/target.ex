defmodule CrucibleDeployment.Targets.Target do
  @moduledoc """
  Behaviour for deployment target backends.
  """

  @type deployment_id :: String.t()
  @type health_status :: %{
          status: :healthy | :degraded | :unhealthy,
          latency_p50: float(),
          latency_p99: float(),
          error_rate: float(),
          requests_per_second: float()
        }

  @callback deploy(config :: map()) :: {:ok, deployment_id()} | {:error, term()}
  @callback update(deployment_id(), config :: map()) :: :ok | {:error, term()}
  @callback terminate(deployment_id()) :: :ok | {:error, term()}
  @callback health_check(deployment_id()) :: {:ok, health_status()} | {:error, term()}
  @callback get_metrics(deployment_id()) :: {:ok, map()} | {:error, term()}
  @callback set_traffic_weight(deployment_id(), weight :: float()) :: :ok | {:error, term()}
end
