using Documenter, REoptLite, JuMP

makedocs(
    sitename="REoptLite.jl Documentation",
    pages = [
        "Home" => "index.md",
        "examples.md",
    ],

)

deploydocs(
    repo = "github.com/NREL/REoptLite.git",
)
