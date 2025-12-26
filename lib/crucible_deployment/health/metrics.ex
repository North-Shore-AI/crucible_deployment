defmodule CrucibleDeployment.Health.Metrics do
  @moduledoc """
  Metric collection helpers for deployment health checks.
  """

  @doc """
  Collect metrics from a target module.
  """
  @spec collect(module(), String.t()) :: {:ok, map()} | {:error, term()}
  def collect(target_module, deployment_id) do
    target_module.get_metrics(deployment_id)
  end
end
