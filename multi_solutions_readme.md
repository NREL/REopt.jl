# Summary
The multiple solutions functionality runs REopt (like `run_reopt`) multiple times to look at the
sensitivity of a number of key results, such as Net Present Value (NPV) and capital cost, on
sizing variations around the optimal technology sizes. The `run_reopt_multi_solutions()` function first runs the optimal case to
identify the cost-effective technologies recommended by REopt. It then re-runs a number of times with user-specified scaling factors applied to each of the cost-optimal techs, and it forces those DER sizes into the solution. 

For each scenario, the scaling factor only applies to one technology at a time, while the other technologies stay at their "combined system optimal" size. If a technology was sized to zero in the optimal combined scenario, then it will kept at zero for all scenarios. If you want to force in a technology that is not optimal, then you can use the e.g. `min_kw` to do that.

# Example use-case/workflow for multi-solutions
#### Specify path to input file:
`fp = "scenarios/multiple_solutions.json"`

#### Specify fractions/ratios of size relative to the optimal size to run. The other techs will all be forced to their same optimal size for each run. If you run with an empty array for size_scale, it will just run the optimal scenario.
`size_scale = [0.8, 1.2]`
#### The function needs to be fed the maximum number of JuMP models to create, so first identify the number of technologies considered. For a scenario which considers 1. PV and 2. Battery (ElectricStorage):
`n_techs = 2`
#### This `max_models` equation uses 2 for optimal+BAU plus however many scenario combinations are possible:
`max_models = 2 + length(size_scale) * n_techs`
#### Define an array of models of length `max_models` along with the specified solver and desired parameters:
`ms = [Model(optimizer_with_attributes(HiGHS.Optimizer, 
    "output_flag" => false, "mip_rel_gap" => 0.001, "log_to_console" => true)) for _ in 1:max_models]`
- Solver options for Cbc.jl: https://github.com/jump-dev/Cbc.jl
- Solver options for HiGHS.jl:  https://ergo-code.github.io/HiGHS/dev/options/definitions/
- Increasing optimality gap (ratioGap for Cbc and mip_rel_gap for HiGHS) to 0.01 (1%) is particularly useful if REopt is taking a long time to solver

### Run the multi-solution scenarios

#### For in-series/sequential runs to reduce number of threads required to 2, set parallel=false; for parallel runs, requiring multiple cores for the multiple threads (see function docstring for more information) set parallel=true:
`results_all, results_summary = REopt.run_reopt_multi_solutions(fp, size_scale, ms; parallel=true)`

#### `results_all` contains all the results data provided by `run_reopt()`, while `results_summary` provides just a selected handful of key results metrics, for easier comparison across scenarios.

#### Here is an example `results_summary` output for `PV` and Battery (`ElectricStorage`) (with just one example sizing scenario, for brevity):
```
   {
    "optimal": {
        "status": "optimal",
        "Simple payback period": 6.72,
        "Net Present Value": 4.23378773e6,
        "status": "optimal",
        "Net capital cost": 6.2236811914e6,
        "Internal Rate of Return %": 12.3,
        "Site life cycle CO2 tonnes": 5518.22
        },        
        "PV": {
            "Capital cost": 2.9387651486586295e6,
            "Annual maintenance cost": 61478.709899999994,
            "Average annual energy produced": 6.131804e6,
            "Rated capacity": 3616.3947
        },
        "ElectricStorage": {
            "Capital cost": 1.3586723305624602e6,
            "Rated inverter capacity": 961.82,
            "Rated energy capacity": 5350.36,
            "Total replacement cost": 770532.6255763071
        }
    "PV_size_scale_0.8": {
        "status": "optimal",        
        "Simple payback period": 6.39,
        "Net Present Value": 4.51702785e6,
        "status": "optimal",
        "Net capital cost": 7.2082109444e6,
        "Internal Rate of Return %": 12.3,
        "Site life cycle CO2 tonnes": 6718.23
        "PV": {
            "Capital cost": 3.4927676627505e6,
            "Annual maintenance cost": 67714.47,
            "Average annual energy produced": 6.901773e6,
            "Rated capacity": 3761.915
        },
        "ElectricStorage": {
            "Capital cost": 2.169465211210427e6,
            "Rated inverter capacity": 1424.1,
            "Rated energy capacity": 7226.28,
            "Total replacement cost": 1.5459781075635727e6
        }
    } 
   }
```

#### Here are some more way to look at the results


##### Print results data to a file
```
open("scenarios/results_summary.json","w") do f
    JSON.print(f, results_summary)
end

open("scenarios/results_all.json","w") do f
    JSON.print(f, results_all)
end
```

##### Print selected results data to the REPL
```
for s in keys(results_summary)
    if results_summary[s]["status"]=="optimal"
        println("NPV for scenario "*s*" = ", results_summary[s]["Net Present Value"])
        println("Capital cost for scenario "*s*" = ", results_summary[s]["Net capital cost"])
    end
end

##### Plot selected results across all sizing scenarios
size_scale_incl_optimal = copy(size_scale)
for (i, scale) in enumerate(size_scale)
    if i > 1 && scale > 1.0 && size_scale[i-1] < 1.0
        insert!(size_scale_incl_optimal, i, 1.0)
    end
end
IRR = []
techs = ["PV", "ElectricStorage"]
for tech in techs
    for scale in size_scale_incl_optimal
        if scale == 1.0
            results_summary_s = results_summary["optimal"]
        else
            results_summary_s = results_summary[tech*"_size_scale_"*string(scale)]
        end
        append!(IRR, [results_summary_s["Internal Rate of Return %"]])
    end

    plot(size_scale_incl_optimal, IRR, marker='o', label=techs)
end
legend(techs)
title("Internal Rate of Return versus size_scale")
```