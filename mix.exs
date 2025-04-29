defmodule LocalFileCacher.MixProject do
  use Mix.Project

  @project_name "Local File Cacher"
  @source_url "https://github.com/arcanemachine/local_file_cacher"
  @version "0.1.1"

  def project do
    [
      app: :local_file_cacher,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description:
        "Create a local file cache for files (e.g. API responses), and prune it to remove old files.",
      package: package(),

      # Docs
      name: @project_name,
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: @project_name,
      extras: ["README.md"],
      formatters: ["html"],
      main: "readme"
    ]
  end

  defp package do
    [
      maintainers: ["Nicholas Moen"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib)
    ]
  end
end
