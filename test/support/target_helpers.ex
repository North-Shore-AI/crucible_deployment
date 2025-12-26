defmodule CrucibleDeployment.TestSupport.TargetAssertions do
  @moduledoc false

  def assert_health_status(%{status: status} = health) do
    unless status in [:healthy, :degraded, :unhealthy] do
      raise "invalid status: #{inspect(status)}"
    end

    Enum.each([:latency_p50, :latency_p99, :error_rate, :requests_per_second], fn key ->
      unless is_number(Map.get(health, key)) do
        raise "missing or invalid #{inspect(key)}"
      end
    end)
  end
end
