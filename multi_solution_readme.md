# Summary
The multiple solutions functionality runs REopt (like `run_reopt`) multiple times to look at the
sensitivity of a number of key results, such as Net Present Value (NPV) and capital cost, on
sizing variations around the optimal technology sizes. The function first runs the optimal case to
identify the cost-effective technologies recommended by REopt. It then re-runs a number of times with scaling factors applied to each of the cost-optimal techs, and it forces those sizes into the
solution. 

If outages are modeled for a resilience analysis, the `resilience` key in the results summary gets populated which includes results from the stochastic outages modeled in the optimization as well as the results from the `simulate_outages()` function which is run to evaluate the resilience performance for all outage start times of the year.

## Example use-case for multi-solutions
### Specify path to input file:
`fp = "scenarios/eaton_multi.json"`

or for resilience:

`fp = "scenarios/eaton_voll.json"`

### Specify fractions/ratios of size relative to the optimal size to run. The other techs will all be forced to the optimal size for each run:
`size_scale = [0.5, 1.5]`
### Need to know the maximum number of JuMP models to create, so first identify the number of technologies considered. So for the eaton_multi.json scenario with PV and Battery (ElectricStorage):
`n_techs = 2`
### This equation uses 2 for optimal+BAU plus however many scenario combinations are possible:
`max_models = 2 + length(size_scale) * n_techs`
### Define an array of models of length `max_models` along with the specified solver and desired parameters:
`ms = [Model(optimizer_with_attributes(HiGHS.Optimizer, 
    "output_flag" => false, "mip_rel_gap" => 0.001, "log_to_console" => true)) for _ in 1:max_models]`
- Solver options for Cbc.jl: https://github.com/jump-dev/Cbc.jl
- Solver options for HiGHS.jl:  https://ergo-code.github.io/HiGHS/dev/options/definitions/
- Increasing optimality gap (ratioGap for Cbc and mip_rel_gap for HiGHS) to 0.01 (1%) is particularly useful if REopt is taking a long time to solver
### In-series/sequential runs to reduce number of threads required to 2:
`results_all, results_summary = REopt.run_reopt_multi_solutions(fp, size_scale, ms; parallel=false)`

## Parallel runs, requiring multiple cores for the multiple threads (see function docstring for more information):
`results_all, results_summary = REopt.run_reopt_multi_solutions(fp, size_scale, ms; parallel=true)`

### Print some interesting data from all the solutions from the results_summary which is created:
```
for s in keys(results_summary)
    println("NPV for scenario "*s*" = ", results_summary[s]["Financial"]["Net Present Value"])
    println("Capital cost for scenario "*s*" = ", results_summary[s]["Financial"]["Net capital cost"])
    println("Resilience duration average (hours) for scenario "*s*" = ", results_summary[s]["resilience"]["Average hours of load served during outage"])
end
```