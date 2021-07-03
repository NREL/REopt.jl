using Documenter, REoptLite, JuMP

makedocs(
    sitename="REoptLite.jl Documentation",
    pages = [
        "Home" => "index.md",
        "REopt Lite" => Any[
            "reopt/examples.md",
            "reopt/inputs.md",
            "reopt/methods.md"
        ],
        "Model Predictive Control" => Any[
            "mpc/examples.md",
            "mpc/inputs.md",
            "mpc/methods.md",
        ]
    ],
    workdir = joinpath(@__DIR__, "..")
)

deploydocs(
    repo = "github.com/NREL/REoptLite.git",
)
