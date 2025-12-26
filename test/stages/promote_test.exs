defmodule CrucibleDeployment.Stages.PromoteTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Stages.Promote

  test "returns error when crucible framework is unavailable" do
    assert {:error, :crucible_framework_not_available} = Promote.run(%{}, %{})
  end
end
