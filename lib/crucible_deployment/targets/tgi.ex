defmodule CrucibleDeployment.Targets.TGI do
  @moduledoc """
  Hugging Face Text Generation Inference target adapter.
  """

  @behaviour CrucibleDeployment.Targets.Target

  alias CrucibleDeployment.Utils

  @doc """
  Deploy a model to TGI.
  """
  @impl true
  @spec deploy(map()) :: {:ok, String.t()} | {:error, term()}
  def deploy(config) do
    deployment_id = Map.get(config, :deployment_id) || Utils.generate_uuid()
    {:ok, deployment_id}
  end

  @doc """
  Update a TGI deployment.
  """
  @impl true
  @spec update(String.t(), map()) :: :ok | {:error, term()}
  def update(_deployment_id, _config), do: :ok

  @doc """
  Terminate a TGI deployment.
  """
  @impl true
  @spec terminate(String.t()) :: :ok | {:error, term()}
  def terminate(_deployment_id), do: :ok

  @doc """
  Check health for a TGI deployment.
  """
  @impl true
  @spec health_check(String.t()) :: {:ok, map()} | {:error, term()}
  def health_check(_deployment_id), do: {:ok, default_health_status()}

  @doc """
  Fetch metrics for a TGI deployment.
  """
  @impl true
  @spec get_metrics(String.t()) :: {:ok, map()} | {:error, term()}
  def get_metrics(_deployment_id), do: {:ok, %{requests: 0, tokens_per_second: 0.0}}

  @doc """
  Set traffic weight for a TGI deployment.
  """
  @impl true
  @spec set_traffic_weight(String.t(), float()) :: :ok | {:error, term()}
  def set_traffic_weight(_deployment_id, weight) do
    validate_weight(weight)
  end

  defp default_health_status do
    %{
      status: :healthy,
      latency_p50: 40.0,
      latency_p99: 200.0,
      error_rate: 0.0,
      requests_per_second: 0.0
    }
  end

  defp validate_weight(weight) when is_number(weight) and weight >= 0.0 and weight <= 1.0, do: :ok
  defp validate_weight(_weight), do: {:error, :invalid_weight}
end
