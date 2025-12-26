defmodule CrucibleDeployment.Health.Rollback do
  @moduledoc """
  Evaluates health signals for rollback decisions.
  """

  @doc """
  Determine whether a health status exceeds rollback thresholds.
  """
  @spec evaluate(map(), map()) :: :ok | {:rollback, :threshold_exceeded}
  def evaluate(health, thresholds) do
    error_rate = Map.get(health, :error_rate, 0.0)
    latency_p99 = Map.get(health, :latency_p99, 0.0)

    if error_rate > thresholds.error_rate or latency_p99 > thresholds.p99_latency do
      {:rollback, :threshold_exceeded}
    else
      :ok
    end
  end
end
