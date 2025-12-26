defmodule CrucibleDeployment.Application do
  @moduledoc """
  OTP application supervisor for crucible_deployment.
  """

  use Application

  @doc false
  @spec start_link(term()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    start(:normal, opts)
  end

  @doc """
  Start the application supervision tree.
  """
  @impl true
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_type, _args) do
    children = [
      CrucibleDeployment.Deployment.Registry,
      CrucibleDeployment.Deployment.Supervisor,
      {Task.Supervisor, name: CrucibleDeployment.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CrucibleDeployment.Supervisor)
  end

  @doc false
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
end
