defmodule CrucibleDeployment.Deployment.Supervisor do
  @moduledoc """
  Dynamic supervisor for deployment state machines.
  """

  use DynamicSupervisor

  @doc """
  Start the deployment supervisor.
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Start a deployment state machine under supervision.
  """
  @spec start_deployment(CrucibleDeployment.Deployment.t(), keyword()) ::
          DynamicSupervisor.on_start_child()
  def start_deployment(deployment, opts) do
    child_spec = {CrucibleDeployment.Deployment.StateMachine, [deployment, opts]}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc false
  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
