using Documenter, REoptLite, JuMP

makedocs(
    sitename="REoptLite.jl Documentation",
    pages = [
        "Home" => "index.md",
        "Usage" => Any[
            "usage/examples.md",
            "usage/inputs.md",
        ],
        "methods.md"
    ],

)

deploydocs(
    repo = "github.com/NREL/REoptLite.git",
)
