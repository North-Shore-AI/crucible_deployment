defmodule CrucibleDeployment.Deployment.Registry do
  @moduledoc """
  Registry for active deployments and their metadata.
  """

  @registry __MODULE__

  @doc """
  Child specification for the deployment registry.
  """
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_args) do
    Registry.child_spec(keys: :unique, name: @registry)
  end

  @doc """
  Register the current process with a deployment record.
  """
  @spec register(CrucibleDeployment.Deployment.t()) :: :ok | {:error, term()}
  def register(deployment) do
    case Registry.register(@registry, deployment.id, deployment) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Update the stored deployment for the current process.
  """
  @spec update(CrucibleDeployment.Deployment.t()) :: :ok | {:error, term()}
  def update(deployment) do
    Registry.update_value(@registry, deployment.id, fn _ -> deployment end)
  end

  @doc """
  Fetch a deployment by ID.
  """
  @spec get(String.t()) :: {:ok, CrucibleDeployment.Deployment.t()} | {:error, :not_found}
  def get(id) do
    case Registry.lookup(@registry, id) do
      [{_pid, deployment}] -> {:ok, deployment}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Fetch the PID for a deployment ID.
  """
  @spec pid(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def pid(id) do
    case Registry.lookup(@registry, id) do
      [{pid, _deployment}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all active deployments.
  """
  @spec list() :: [CrucibleDeployment.Deployment.t()]
  def list do
    Registry.select(@registry, [{{:"$1", :_, :"$2"}, [], [:"$2"]}])
  end
end
