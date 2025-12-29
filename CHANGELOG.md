# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2025-12-28

### Changed
- Broadened Elixir version requirement to ~> 1.14 for wider compatibility
- Updated crucible_framework dependency to ~> 0.5.2
- Updated crucible_model_registry dependency to ~> 0.3.1
- Updated telemetry dependency to ~> 1.3

## [0.2.0] - 2025-12-27

### Added
- Conformance tests for all deployment stages
- README documentation for stage contracts and options

### Changed
- Updated crucible_framework dependency to ~> 0.5.0 (required describe/1 contract)

### Stages
- Deploy - Supports vLLM, TGI, Triton, SageMaker, Kubernetes targets
- Promote - Promote canary/staged deployments to full traffic
- Rollback - Roll back to previous version

## [0.1.0] - 2025-12-25

### Added
- Initial release
- Model deployment orchestration
- Kubernetes backend support (optional)
- Health checking and rollback capabilities
- Crucible Framework integration
