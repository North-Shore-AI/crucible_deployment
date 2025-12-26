defmodule CrucibleDeployment.Stages.DeployTest do
  use ExUnit.Case, async: true

  alias CrucibleDeployment.Stages.Deploy

  test "returns error when crucible framework is unavailable" do
    assert {:error, :crucible_framework_not_available} = Deploy.run(%{}, %{})
  end
end
