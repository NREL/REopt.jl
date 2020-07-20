using JuMP
include("../src/REoptLite.jl")
using .REoptLite

model = Model()
path_to_scenario = abspath(joinpath(
    dirname(Base.find_package(REoptLite, "REoptLite")), "..", "test", "scenarios", "no_techs.json"
    )
)
build_reopt!(model, path_to_scenario)
