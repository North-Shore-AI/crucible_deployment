defmodule CrucibleDeployment do
  @moduledoc """
  Model deployment with progressive rollout strategies.
  """

  alias CrucibleDeployment.Config
  alias CrucibleDeployment.Deployment
  alias CrucibleDeployment.Deployment.Registry
  alias CrucibleDeployment.Deployment.StateMachine
  alias CrucibleDeployment.Deployment.Supervisor, as: DeploymentSupervisor
  alias CrucibleDeployment.Utils

  @type deploy_opts :: [
          target: atom(),
          strategy: atom(),
          model_path: Path.t(),
          convert_to: atom() | nil,
          canary_config: map() | nil
        ]

  @doc """
  Deploy a model to a target backend using a rollout strategy.
  """
  @spec deploy(map() | keyword()) :: {:ok, Deployment.t()} | {:error, term()}
  def deploy(opts) do
    opts = normalize_opts(opts)

    with {:ok, target_module} <- Config.target_module(Map.get(opts, :target, :noop)),
         {:ok, strategy_module} <- Config.strategy_module(Map.get(opts, :strategy, :replace)),
         {:ok, model_name} <- fetch_required(opts, :model_name),
         {:ok, config} <- build_config(opts) do
      deployment = %Deployment{
        id: Utils.generate_uuid(),
        model_version_id: Map.get(opts, :model_version_id),
        model_name: model_name,
        target: Map.get(opts, :target, :noop),
        strategy: Map.get(opts, :strategy, :replace),
        state: :deploying,
        config: config,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        metrics: %{}
      }

      start_opts =
        []
        |> Keyword.put(:target_module, target_module)
        |> Keyword.put(:strategy_module, strategy_module)
        |> Keyword.put(:strategy_opts, strategy_opts(opts))
        |> Keyword.put(:auto_start, Map.get(opts, :auto_start, true))
        |> Keyword.put(:step_interval, Map.get(opts, :step_interval, 0))
        |> Keyword.put(:check_interval, Map.get(opts, :check_interval))
        |> Keyword.put(:rate_limit_ms, Map.get(opts, :rate_limit_ms))
        |> Keyword.put(:task_supervisor, Map.get(opts, :task_supervisor))

      case DeploymentSupervisor.start_deployment(deployment, start_opts) do
        {:ok, _pid} ->
          emit_telemetry(:deploy, deployment)
          {:ok, deployment}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Fetch status information for a deployment.
  """
  @spec get_status(Deployment.t() | String.t()) :: {:ok, map()} | {:error, term()}
  def get_status(deployment_or_id) do
    with {:ok, deployment} <- resolve_deployment(deployment_or_id),
         {:ok, target_module} <- Config.target_module(deployment.target),
         target_id <- Map.get(deployment.config, :target_deployment_id, deployment.id),
         {:ok, health} <- target_module.health_check(target_id),
         {:ok, metrics} <- target_module.get_metrics(target_id) do
      {:ok,
       %{
         state: deployment.state,
         target: deployment.target,
         strategy: deployment.strategy,
         health: health,
         metrics: metrics
       }}
    end
  end

  @doc """
  Promote a deployment to full traffic.
  """
  @spec promote(Deployment.t() | String.t()) :: :ok | {:error, term()}
  def promote(deployment_or_id) do
    with {:ok, pid} <- resolve_pid(deployment_or_id) do
      StateMachine.promote(pid)
    end
  end

  @doc """
  Roll back a deployment.
  """
  @spec rollback(Deployment.t() | String.t()) :: :ok | {:error, term()}
  def rollback(deployment_or_id) do
    with {:ok, pid} <- resolve_pid(deployment_or_id) do
      StateMachine.rollback(pid)
    end
  end

  @doc """
  Terminate a deployment.
  """
  @spec terminate(Deployment.t() | String.t()) :: :ok | {:error, term()}
  def terminate(deployment_or_id) do
    with {:ok, pid} <- resolve_pid(deployment_or_id) do
      StateMachine.terminate(pid)
    end
  end

  @doc """
  Convert a model artifact to a new format.
  """
  @spec convert(Path.t(), atom(), keyword()) :: {:ok, Path.t()} | {:error, term()}
  def convert(source_path, target_format, opts \\ []) do
    with {:ok, converter} <- Config.converter_module(target_format) do
      converter.convert(source_path, target_format, opts)
    end
  end

  @doc """
  List active deployments.
  """
  @spec list_deployments() :: [Deployment.t()]
  def list_deployments do
    Registry.list()
  end

  @doc """
  Fetch a deployment by ID.
  """
  @spec get_deployment(String.t()) :: {:ok, Deployment.t()} | {:error, :not_found}
  def get_deployment(id) do
    Registry.get(id)
  end

  defp normalize_opts(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp normalize_opts(opts) when is_map(opts), do: opts

  defp fetch_required(opts, key) do
    case Map.fetch(opts, key) do
      {:ok, value} when value != nil -> {:ok, value}
      _ -> {:error, {:missing_option, key}}
    end
  end

  defp build_config(opts) do
    config = Map.get(opts, :config, %{})
    config = maybe_put_model_path(config, Map.get(opts, :model_path))

    case Map.get(opts, :convert_to) do
      nil ->
        {:ok, config}

      format ->
        source_path = Map.get(opts, :model_path) || Map.get(config, :model_path)

        if source_path do
          convert_opts = Map.get(opts, :convert_opts, [])

          with {:ok, converted_path} <- convert(source_path, format, convert_opts) do
            {:ok, Map.put(config, :model_path, converted_path)}
          end
        else
          {:error, :missing_model_path}
        end
    end
  end

  defp maybe_put_model_path(config, nil), do: config
  defp maybe_put_model_path(config, path), do: Map.put(config, :model_path, path)

  defp strategy_opts(opts) do
    Map.get(opts, :strategy_opts) || Map.get(opts, :canary_config) || %{}
  end

  defp resolve_deployment(%Deployment{} = deployment), do: {:ok, deployment}
  defp resolve_deployment(id) when is_binary(id), do: Registry.get(id)

  defp resolve_pid(%Deployment{} = deployment), do: Registry.pid(deployment.id)
  defp resolve_pid(id) when is_binary(id), do: Registry.pid(id)

  defp emit_telemetry(event, deployment) do
    :telemetry.execute(
      [:crucible_deployment, event],
      %{count: 1},
      %{deployment_id: deployment.id, target: deployment.target, strategy: deployment.strategy}
    )
  end
end
