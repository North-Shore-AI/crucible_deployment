defmodule CrucibleDeployment.Stages.Rollback do
  @moduledoc """
  Crucible stage for rolling back a deployment.
  """

  if Code.ensure_loaded?(Crucible.Stage) do
    @behaviour Crucible.Stage
  end

  @impl true
  def describe(_opts) do
    %{
      name: :rollback,
      description: "Rolls back a deployment to a previous version",
      required: [],
      optional: [],
      types: %{}
    }
  end

  @doc """
  Run the rollback stage when crucible_framework is available.
  """
  @impl true
  @spec run(term(), map()) :: {:ok, term()} | {:error, term()}
  def run(context, _opts) do
    if crucible_available?(context) do
      context_module = Module.concat([:Crucible, :Context])
      deployment = context_module.get_artifact(context, :deployment)

      :ok = CrucibleDeployment.rollback(deployment)
      {:ok, context}
    else
      {:error, :crucible_framework_not_available}
    end
  end

  defp crucible_available?(context) do
    Code.ensure_loaded?(Module.concat([:Crucible, :Context])) and
      is_struct(context, Module.concat([:Crucible, :Context]))
  end
end
