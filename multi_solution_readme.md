# Summary
The multiple solutions functionality runs REopt (like `run_reopt`) multiple times to look at the
sensitivity of a number of key results, such as Net Present Value (NPV) and capital cost, on
sizing variations around the optimal technology sizes. The function first runs the optimal case to
identify the cost-effective technologies recommended by REopt. It then re-runs a number of times with scaling factors applied to each of the cost-optimal techs, and it forces those sizes into the
solution. 

# Example use-case for multi-solutions
fp = "scenarios/eaton_multi.json"
# Fractions/ratios of size relative to the optimal size
# For each technology which is sized, multiply the size by the size_scale for a different solution
# The other techs will all be at 1.0/optimal size for the scaling of other techs
size_scale = [0.5, 1.5]
# Need to know max number of JuMP model to create, so identify the number of technologies considered
n_techs = 2
# Max models is 2 for optimal+BAU and then however many scenarios are possible
max_models = 2 + length(size_scale) * n_techs
# Hard to duplicate JuMP models dynamically, so conservatively instantiate max possible models
# Solver options for Cbc.jl: https://github.com/jump-dev/Cbc.jl
# Solver options for HiGHS.jl:  https://ergo-code.github.io/HiGHS/dev/options/definitions/
# Increasing optimality gap (allowableGap for Cbc and mip_rel_gap for HiGHS) to 0.01 (1%) is particularly useful if REopt is taking a long time to solver
ms = [Model(optimizer_with_attributes(HiGHS.Optimizer, 
    "output_flag" => false, "mip_rel_gap" => 0.001, "log_to_console" => true)) for _ in 1:max_models]

# In-series/sequential run_reopt:
results_all, results_summary = REopt.run_reopt_multi_solutions(fp, size_scale, ms; parallel=false)

# Parallel run_reopt:
results_all, results_summary = REopt.run_reopt_multi_solutions(fp, size_scale, ms; parallel=true)

# Print some interesting data from all the solutions
for s in keys(results_summary)
    println("NPV for scenario "*s*" = ", results_summary[s]["Financial"]["Net Present Value"])
    println("Capital cost for scenario "*s*" = ", results_summary[s]["Financial"]["Net capital cost"])
end