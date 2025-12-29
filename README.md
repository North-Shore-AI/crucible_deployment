# CrucibleDeployment

<p align="center">
  <img src="assets/crucible_deployment.svg" alt="CrucibleDeployment Logo" width="200"/>
</p>

<p align="center">
  <strong>Platform-agnostic model deployment with progressive rollout strategies, format conversion, and health monitoring</strong>
</p>

<p align="center">
  <a href="https://hex.pm/packages/crucible_deployment"><img src="https://img.shields.io/hexpm/v/crucible_deployment.svg" alt="Hex Version"/></a>
  <a href="https://hexdocs.pm/crucible_deployment"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="Hex Docs"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"/></a>
</p>

---

## Features

- Target adapters for vLLM, Ollama, TGI, Hugging Face, Kubernetes, and Noop
- Rollout strategies: Replace, Blue/Green, Canary, A/B
- Format converters: GGUF, ONNX, TensorRT
- Continuous health checks with auto-rollback signals
- Crucible framework Stage integration (optional)
- Telemetry events for deploy, promote, rollback, and health checks

## Installation

```elixir
# mix.exs
{:crucible_deployment, "~> 0.2.1"}
```

## Quick Start

```elixir
{:ok, deployment} = CrucibleDeployment.deploy(%{
  model_name: "llama-3.1-8b",
  target: :vllm,
  strategy: :canary,
  config: %{endpoint: "https://vllm.internal"}
})

{:ok, status} = CrucibleDeployment.get_status(deployment)
```

## Targets

Targets implement `CrucibleDeployment.Targets.Target`:

- `:vllm` → `CrucibleDeployment.Targets.VLLM`
- `:ollama` → `CrucibleDeployment.Targets.Ollama`
- `:tgi` → `CrucibleDeployment.Targets.TGI`
- `:huggingface` → `CrucibleDeployment.Targets.HuggingFace`
- `:kubernetes` → `CrucibleDeployment.Targets.Kubernetes`
- `:noop` → `CrucibleDeployment.Targets.Noop`

You can register custom targets via configuration:

```elixir
config :crucible_deployment,
  targets: %{my_target: MyApp.DeploymentTarget}
```

## Strategies

Strategies implement `CrucibleDeployment.Strategies.Strategy`:

- `:replace`
- `:blue_green`
- `:canary`
- `:ab_test`

Pass strategy options via `:strategy_opts` or `:canary_config`:

```elixir
CrucibleDeployment.deploy(%{
  model_name: "llama-3.1-8b",
  target: :vllm,
  strategy: :canary,
  strategy_opts: %{steps: [10, 30, 50, 100], evaluation_period: :timer.minutes(2)}
})
```

## Converters

Converters implement `CrucibleDeployment.Converters.Converter` and support:

- `:gguf`
- `:onnx`
- `:tensorrt`

```elixir
{:ok, path} = CrucibleDeployment.convert("/models/checkpoint.bin", :gguf, output_path: "/models/model.gguf")
```

## Health Monitoring

`CrucibleDeployment.Health.Monitor` performs periodic checks and emits telemetry:

- `[:crucible_deployment, :health_check]`

The state machine listens for health alerts and triggers rollback when thresholds are exceeded.

## Telemetry

Emitted events include:

- `[:crucible_deployment, :deploy]`
- `[:crucible_deployment, :promote]`
- `[:crucible_deployment, :rollback]`
- `[:crucible_deployment, :health_check]`

## Deployment Stages

This package provides Crucible stages for model deployment:

- `:deploy` - Deploy model to inference target (vLLM, TGI, Triton, SageMaker, Kubernetes)
- `:deployment_promote` - Promote canary/staged deployment to full traffic
- `:rollback` - Roll back deployment to previous version

All stages implement the `Crucible.Stage` behaviour with full describe/1 schemas.

### Stage Options

**Deploy Stage (`:deploy`):**
- `target` - Inference target (`:vllm`, `:tgi`, `:triton`, `:sagemaker`, `:kubernetes`)
- `strategy` - Rollout strategy (`:canary`, `:blue_green`, `:rolling`, `:recreate`)
- `config` - Target-specific configuration map

**Promote Stage (`:deployment_promote`):**
- No options required. Promotes the deployment from context artifacts.

**Rollback Stage (`:rollback`):**
- No options required. Rolls back the deployment from context artifacts.

## Crucible Framework Integration

Stages are available when `crucible_framework` is present:

- `CrucibleDeployment.Stages.Deploy`
- `CrucibleDeployment.Stages.Rollback`
- `CrucibleDeployment.Stages.Promote`

If the framework is unavailable, stages return `{:error, :crucible_framework_not_available}`.

## Testing

```bash
mix test
```

## Development Notes

- `Task.Supervisor` is used for background rollout steps.
- Deployment IDs are UUIDv4 strings.
- Registry keeps active deployments in-memory via `Registry`.

## License

Internal use.
