using Revise
using REopt
using JSON
using DelimitedFiles
using PlotlyJS
using Dates
using Test
using JuMP
using HiGHS
using DotEnv
DotEnv.load!()

###############   Multiple CHPs Test    ###################
input_data = JSON.parsefile("./scenarios/multiple_chps.json")
s = Scenario(input_data)
inputs = REoptInputs(s)

m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01, "output_flag" => false, "log_to_console" => false))
results = run_reopt(m1, inputs)
# m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01, "output_flag" => false, "log_to_console" => false))
# results = run_reopt([m1,m2], inputs)

# Check that both CHPs are in results
@test length(results["CHP"]) == 2
CHP_recip_engine = results["CHP"][findfirst(chp -> chp["name"] == "CHP_recip_engine", results["CHP"])]
CHP_micro_turbine = results["CHP"][findfirst(chp -> chp["name"] == "CHP_micro_turbine", results["CHP"])]

# Check that each CHP has sizing results
@test CHP_recip_engine["size_kw"] > 10.0
@test CHP_micro_turbine["size_kw"] > 10.0

# Check that results include electric production for each CHP
@test sum(CHP_recip_engine["electric_production_series_kw"]) > 5000.0
@test sum(CHP_micro_turbine["electric_production_series_kw"]) > 5000.0