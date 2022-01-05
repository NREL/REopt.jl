# Examples
To use REopt Lite you will need to have a solver installed. REoptLite.jl has been tested with Xpress, Cbc, and CPLEX solvers, but it should work with other Linear Progam solvers (for PV and Storage scenarios) or Mixed Integer Linear Program solvers (for scenarios with outages and/or Generators).

## Basic
```julia
using REoptLite, JuMP, Cbc

m = Model(Cbc.Optimizer)
results = run_reopt(m, "test/scenarios/pv_storage.json")
```
See [pv_storage.json](https://github.com/NREL/REoptLite/blob/master/test/scenarios/pv_storage.json) for details on the Scenario.

For more on the `scenario.json` see the [REopt Inputs](@ref) section.

In order to calculate additional result metrics you can run the [BAUScenario](@ref) scenario in parallel by providing two `JuMP.Model`s like so:
```julia
m1 = Model(Cbc.Optimizer)
m2 = Model(Cbc.Optimizer)
results = run_reopt([m1,m2], "./scenarios/pv_storage.json")
```
With the [BAUScenario](@ref) results we can calculate the net present value of the optimal system.

!!! note
    The `Settings.run_bau` is `true` by default and so there is no need to change the `run_bau` value in general since it is ignored when only one `JuMP.Model` is passed to the `run_reopt` method. We include the `run_bau` option to align with the REopt API Settings.

## Advanced

### Modifying the mathematical model
Using the `build_reopt!` method and `JuMP` methods one can modify the REopt model before optimizing.
In the following example we add a cost for curtailed PV power.
```julia
using Xpress
using JuMP
using REoptLite

m = JuMP.Model(Xpress.Optimizer)

p = REoptInputs("scenarios/pv_storage.json");

build_reopt!(m, p)

#= 
replace the original objective, which is to Min the Costs,
with the Costs + 100 * (total curtailed PV power)
=#  
JuMP.@objective(m, Min, m[:Costs] + 100 * sum(m[:dvCurtail]["PV", ts] for ts in p.time_steps));

JuMP.optimize!(m)  # normally this command is called in run_reopt

results = reopt_results(m, p)
```
One can also add variables and constraints to the model before optimizing using the JuMP commands.

!!! note
    The `JuMP.` prefixes are not necessary. We include them in the example to show which commands come from JuMP.
