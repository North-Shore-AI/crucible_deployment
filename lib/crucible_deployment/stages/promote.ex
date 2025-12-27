defmodule CrucibleDeployment.Stages.Promote do
  @moduledoc """
  Crucible stage for promoting a deployment to full traffic.
  """

  if Code.ensure_loaded?(Crucible.Stage) do
    @behaviour Crucible.Stage
  end

  @impl true
  def describe(_opts) do
    %{
      name: :deployment_promote,
      description: "Promotes a canary/staged deployment to receive full traffic",
      required: [],
      optional: [],
      types: %{}
    }
  end

  @doc """
  Run the promote stage when crucible_framework is available.
  """
  @impl true
  @spec run(term(), map()) :: {:ok, term()} | {:error, term()}
  def run(context, _opts) do
    if crucible_available?(context) do
      context_module = Module.concat([:Crucible, :Context])
      deployment = context_module.get_artifact(context, :deployment)

      :ok = CrucibleDeployment.promote(deployment)
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
