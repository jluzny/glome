defmodule BasicProject.MixProject do
  use Mix.Project

  @app :glome
  @version "0.4.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Gleam compilation config
      compilers: [:gleam | Mix.compilers()],
      archives: [mix_gleam: "~> 0.6"],
      aliases: ["deps.get": ["deps.get", "gleam.deps.get"]],
      erlc_paths: [
        "build/dev/erlang/#{@app}/_gleam_artefacts",
        "build/dev/erlang/#{@app}/build"
      ],
      erlc_include_path: "build/dev/erlang/#{@app}/include",
      prune_code_paths: false
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gleam_stdlib, "~> 0.34 or ~> 1.0"},
      {:nerf, path: "../../../gleam/libs/nerf"},
      {:gleam_json, "~> 1.0"},
      {:gleam_otp, "~> 0.10.0"},
      # {:gleam_erlang, "~> 0.24"},
      {:gleam_httpc, "~> 2.1"},
      {:gleam_http, "~> 3.6"},
      {:gleeunit, "1.1.2", only: [:dev, :test], runtime: false}
    ]
  end
end
