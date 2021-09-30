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
!!! note
    The `Settings.run_bau` is `true` by default and so there is no need to change the `run_bau` value in general since it is ignored when only one `JuMP.Model` is passed to the `run_reopt` method. We include the `run_bau` option to align with the REopt API Settings.

## Advanced

### Manipulating Inputs
A `scenario.json` goes through two conversion steps before the data is passed to the JuMP model:
1. Conversion to a [Scenario](@ref) struct
2. Conversion to a [REoptInputs](@ref) struct
`REoptInputs` captures all the data arrays and sets necessary to build the JuMP model, and it can be manually modified before building the model:
```julia
using Xpress
using JuMP
using REoptLite

m = Model(Xpress.Optimizer)

inputs = REoptInputs("path/to/scenario.json")
# ... modify the inputs ...
results = run_reopt(m, inputs)
```
