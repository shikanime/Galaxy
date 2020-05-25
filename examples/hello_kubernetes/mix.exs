defmodule HelloKubernetes.MixProject do
  use Mix.Project

  def project do
    [
      app: :hello_kubernetes,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  # Run "mix help release" to learn about releases.
  defp releases do
    [
      hello_kubernetes: [
        include_executables_for: [:unix],
        include_erts: false,
        applications: [
          runtime_tools: :permanent,
          hello_kubernetes: :permanent
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:galaxy, "~> 0.6", path: "../../"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
