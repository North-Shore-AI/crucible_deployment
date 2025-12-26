defmodule CrucibleDeployment.Config do
  @moduledoc """
  Configuration helpers for resolving targets, strategies, and converters.
  """

  @default_targets %{
    vllm: CrucibleDeployment.Targets.VLLM,
    ollama: CrucibleDeployment.Targets.Ollama,
    tgi: CrucibleDeployment.Targets.TGI,
    huggingface: CrucibleDeployment.Targets.HuggingFace,
    kubernetes: CrucibleDeployment.Targets.Kubernetes,
    noop: CrucibleDeployment.Targets.Noop
  }

  @default_strategies %{
    replace: CrucibleDeployment.Strategies.Replace,
    blue_green: CrucibleDeployment.Strategies.BlueGreen,
    canary: CrucibleDeployment.Strategies.Canary,
    ab_test: CrucibleDeployment.Strategies.ABTest
  }

  @default_converters %{
    gguf: CrucibleDeployment.Converters.GGUF,
    onnx: CrucibleDeployment.Converters.ONNX,
    tensorrt: CrucibleDeployment.Converters.TensorRT
  }

  @doc """
  Resolve a target module from configuration or a direct module reference.
  """
  @spec target_module(atom()) :: {:ok, module()} | {:error, :unknown_target}
  def target_module(target) when is_atom(target) do
    targets = Application.get_env(:crucible_deployment, :targets, @default_targets)

    case Map.fetch(targets, target) do
      {:ok, module} ->
        {:ok, module}

      :error ->
        if Code.ensure_loaded?(target) do
          {:ok, target}
        else
          {:error, :unknown_target}
        end
    end
  end

  @doc """
  Resolve a rollout strategy module from configuration or a direct module reference.
  """
  @spec strategy_module(atom()) :: {:ok, module()} | {:error, :unknown_strategy}
  def strategy_module(strategy) when is_atom(strategy) do
    strategies = Application.get_env(:crucible_deployment, :strategies, @default_strategies)

    case Map.fetch(strategies, strategy) do
      {:ok, module} ->
        {:ok, module}

      :error ->
        if Code.ensure_loaded?(strategy) do
          {:ok, strategy}
        else
          {:error, :unknown_strategy}
        end
    end
  end

  @doc """
  Resolve a converter module from configuration or a direct module reference.
  """
  @spec converter_module(atom()) :: {:ok, module()} | {:error, :unknown_converter}
  def converter_module(format) when is_atom(format) do
    converters = Application.get_env(:crucible_deployment, :converters, @default_converters)

    case Map.fetch(converters, format) do
      {:ok, module} ->
        {:ok, module}

      :error ->
        if Code.ensure_loaded?(format) do
          {:ok, format}
        else
          {:error, :unknown_converter}
        end
    end
  end
end
