defmodule Galaxy.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :galaxy,
      version:  @version,
      name: "Galaxy",
      package: package(),
      elixir: "~> 1.10",
      docs: docs(),
      deps: deps(),
      package: package(),
      description: "Seamless node clustering for Elixir",
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Galaxy.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Shikanime Deva"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/Shikanime/Galaxy"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "Galaxy",
      source_ref: "v#{@version}",
      source_url: "https://github.com/Shikanime/Galaxy",
    ]
  end
end
