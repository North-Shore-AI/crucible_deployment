defmodule CrucibleDeployment.Stages.Deploy do
  @moduledoc """
  Crucible stage for deploying a model version.
  """

  @doc """
  Run the deployment stage when crucible_framework is available.
  """
  @spec run(term(), map()) :: {:ok, term()} | {:error, term()}
  def run(context, opts) do
    if crucible_available?(context) do
      context_module = Module.concat([:Crucible, :Context])
      model_version = context_module.get_artifact(context, :model_version)

      {:ok, deployment} =
        CrucibleDeployment.deploy(%{
          model_version_id: Map.get(model_version, :id),
          model_name: model_version.model.name,
          target: opts[:target] || :vllm,
          strategy: opts[:strategy] || :canary,
          config: opts[:config] || %{}
        })

      context = context_module.put_artifact(context, :deployment, deployment)

      context = context_module.put_artifact(context, :deployment_id, deployment.id)

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
