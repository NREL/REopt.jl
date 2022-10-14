using Revise
using JuMP
using JSON
using Xpress
using Test
using REopt
using HiGHS
using DelimitedFiles


# @testset "CHP Sizing" begin
# Sizing CHP with non-constant efficiency, no cost curve, no unavailability_periods
data_sizing = JSON.parsefile("./scenarios/chp_sizing.json")
s = Scenario(data_sizing)
inputs = REoptInputs(s)
m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
results = run_reopt(m, inputs)

@test round(results["CHP"]["size_kw"], digits=0) ≈ 468.7 atol=1.0
@test round(results["Financial"]["lcc"], digits=0) ≈ 1.3476e7 atol=1.0e7
# end