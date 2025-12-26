defmodule CrucibleDeployment.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/North-Shore-AI/crucible_deployment"

  def project do
    [
      app: :crucible_deployment,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [dialyzer: :dev],
      deps: deps(),
      dialyzer: [
        plt_ignore_apps: [:xmerl]
      ],
      name: "CrucibleDeployment",
      description: "Model deployment orchestration with health checking and rollback",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CrucibleDeployment.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:finch, "~> 0.18"},
      # {:k8s, "~> 2.6", optional: true},
      {:crucible_framework, "~> 0.4.0"},
      {:crucible_ir, "~> 0.2.0"},
      {:crucible_model_registry, "~> 0.1.0"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:mox, "~> 1.1", only: :test},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "CrucibleDeployment",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      assets: %{"assets" => "assets"},
      logo: "assets/crucible_deployment.svg"
    ]
  end

  defp package do
    [
      name: "crucible_deployment",
      description: "Model deployment orchestration with health checking and rollback",
      files: ~w(README.md CHANGELOG.md mix.exs LICENSE lib assets),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Online documentation" => "https://hexdocs.pm/crucible_deployment"
      },
      maintainers: ["nshkrdotcom"]
    ]
  end
end
