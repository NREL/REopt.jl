# using Revise
# using REopt
# using JSON
# using DelimitedFiles
# using PlotlyJS
# using Dates
# using Test
# using JuMP
# using HiGHS
# using DotEnv
# DotEnv.load!()

###############   Multiple CHPs Test    ###################

# With BAU Scenario
input_data = JSON.parsefile("./scenarios/multiple_chps.json")
s = Scenario(input_data)
inputs = REoptInputs(s)

m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.05, "output_flag" => false, "log_to_console" => false))
m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.05, "output_flag" => false, "log_to_console" => false))
results = run_reopt([m1,m2], inputs)

@test length(results["CHP"]) == 2
CHP_recip_engine = results["CHP"][findfirst(chp -> chp["name"] == "CHP_recip_engine", results["CHP"])]
CHP_micro_turbine = results["CHP"][findfirst(chp -> chp["name"] == "CHP_micro_turbine", results["CHP"])]

# Check that each CHP has sizing results
@test CHP_recip_engine["size_kw"] > 10.0
@test CHP_micro_turbine["size_kw"] > 10.0

# Check that results include electric production for each CHP
@test sum(CHP_recip_engine["electric_production_series_kw"]) > 500.0
@test sum(CHP_micro_turbine["electric_production_series_kw"]) > 500.0

# Test that LCC matches sum of discounted cashflows for optimal case (within 0.1% tolerance)
# Note, cashflows are negative where lcc is positive, so negating cashflows in comparison
optimal_lcc = results["Financial"]["lcc"]
optimal_cashflow_sum = -1*sum(results["Financial"]["offtaker_discounted_annual_free_cashflows"])
@test isapprox(optimal_lcc, optimal_cashflow_sum, rtol=0.001)

# Test that LCC matches sum of discounted cashflows for BAU case (within 0.1% tolerance)
bau_lcc = results["Financial"]["lcc_bau"]
bau_cashflow_sum = -1*sum(results["Financial"]["offtaker_discounted_annual_free_cashflows_bau"])
@test isapprox(bau_lcc, bau_cashflow_sum, rtol=0.001)

# Add a test to compare npv with difference in optimal and bau cashflows
npv_calculated = bau_cashflow_sum - optimal_cashflow_sum
npv_reported = results["Financial"]["npv"]
@test isapprox(npv_calculated, npv_reported, rtol=0.001)
