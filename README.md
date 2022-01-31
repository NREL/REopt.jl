# REopt Julia package
This package is currently under development and only has a subset of capabilities of the REopt model used in the [REopt API](https://github.com/NREL/REopt_API). We expect to have the first stable release by April 2022.

Note: this package has been tested with Julia 1.4, 1.5, and 1.6 and may not be compatible with older versions.

For more information please see the documentation:
<!-- [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://nrel.github.io/REopt.jl/stable) -->
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://nrel.github.io/REopt.jl/dev)


## Quick Start
Evaluating only `PV` and `Storage` requires a linear program solver. Adding a generator and/or multiple outages makes the problem mixed-integer linear, and thus requires a MILP solver. See https://jump.dev/JuMP.jl/stable/installation/ for a list of solvers. The REopt package has been tested with `Xpress`, `Cbc` and `CPLEX`.
### Example
```
using Xpress
using JuMP
using REopt

m = Model(Xpress.Optimizer)
results = run_reopt(m, "path/to/scenario.json")
```
See the `test/scenarios` directory for examples of `scenario.json`.

For more details see the [documentation](https://nrel.github.io/REopt.jl/dev).
