# Examples
To use REopt Lite you will need to have a solver installed. REoptLite.jl has been tested with Xpress, Cbc, and CPLEX solvers, but it should work with other Linear Progam solvers (for PV and Storage scenarios) or Mixed Integer Linear Program solvers (for scenarios with outages and/or Generators).

## Basic
```julia
using Xpress
using JuMP
using REoptLite

m = Model(Xpress.Optimizer)
results = run_reopt(m, "path/to/scenario.json")
```
The `results` is a `Dict`.