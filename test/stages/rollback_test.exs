defmodule CrucibleDeployment.Stages.RollbackTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Stages.Rollback

  test "returns error when crucible framework is unavailable" do
    assert {:error, :crucible_framework_not_available} = Rollback.run(%{}, %{})
  end
end
