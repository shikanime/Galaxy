defmodule Galaxy.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :galaxy,
      version: "0.4.0",
      name: "Galaxy",
      description: description(),
      package: package(),
      source_url: "https://github.com/Shikanime/Galaxy",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Galaxy.Application, []}
    ]
  end

  defp description do
    """
    Seamless Elixir node clustering.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", ".formatter.exs"],
      maintainers: ["Shikanime Deva"],
      licenses: ["MIT"],
      links: %{
        Documentation: "https://hexdocs.pm/galaxy",
        GitHub: "https://github.com/Shikanime/Galaxy"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
