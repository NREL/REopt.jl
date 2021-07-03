# Examples
To use REopt Lite you will need to have a solver installed. REoptLite.jl has been tested with Xpress, Cbc, and CPLEX solvers, but it should work with other Linear Progam solvers (for PV and Storage scenarios) or Mixed Integer Linear Program solvers (for scenarios with outages and/or Generators).

## Basic
```@example
using REoptLite, JuMP, Cbc

m = Model(Cbc.Optimizer)
results = run_reopt(m, "test/scenarios/pv_storage.json")
```
See [pv_storage.json](https://github.com/NREL/REoptLite/blob/master/test/scenarios/pv_storage.json) for details on the Scenario.

For more on the `scenario.json` see the [REopt Inputs](@ref) section.

## Advanced

### Manipulating Inputs
A `scenario.json` goes through two conversion steps before the data is passed to the JuMP model:
1. Conversion to a [Scenario](@ref) struct
2. Converstion to a [REoptInputs](@ref) struct
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
