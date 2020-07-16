using JuMP
include("../src/REoptLite.jl")
using .REoptLite

model = Model()
build_reopt!(model, "../test/scenario_no_techs.json")
