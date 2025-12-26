defmodule CrucibleDeployment.Deployment.StateMachineTest do
  use ExUnit.Case, async: false

  alias CrucibleDeployment.Deployment.Registry
  alias CrucibleDeployment.Deployment.StateMachine
  alias CrucibleDeployment.TestSupport

  defmodule StrategyStub do
    @behaviour CrucibleDeployment.Strategies.Strategy

    def init(deployment, _opts), do: {:ok, %{deployment: deployment, step: 0}}

    def step(%{step: 0} = state), do: {:continue, %{state | step: 1}}

    def step(%{step: 1}),
      do: {:complete, %{status: :completed, deployment_id: "target-1", metrics: %{}}}

    def rollback(_state), do: :ok
  end

  defmodule StrategyRollbackStub do
    @behaviour CrucibleDeployment.Strategies.Strategy

    def init(deployment, _opts), do: {:ok, %{deployment: deployment, step: 0}}

    def step(_state), do: {:rollback, :failed}

    def rollback(_state), do: :ok
  end

  setup do
    unless Process.whereis(Registry) do
      start_supervised!(Registry)
    end

    :ok
  end

  test "advances and completes when steps succeed" do
    deployment = TestSupport.build_deployment(:replace, :noop)

    {:ok, pid} =
      StateMachine.start_link(deployment,
        strategy_module: StrategyStub,
        auto_start: false
      )

    assert {:ok, _} = Registry.get(deployment.id)

    assert :ok = StateMachine.tick(pid)
    assert %{state: :deploying} = StateMachine.status(pid)

    assert :ok = StateMachine.tick(pid)
    assert %{state: :active} = StateMachine.status(pid)
  end

  test "marks deployment as rolling_back on rollback" do
    deployment = TestSupport.build_deployment(:replace, :noop)

    {:ok, pid} =
      StateMachine.start_link(deployment,
        strategy_module: StrategyRollbackStub,
        auto_start: false
      )

    assert :ok = StateMachine.tick(pid)
    assert %{state: :rolling_back} = StateMachine.status(pid)
  end
end
