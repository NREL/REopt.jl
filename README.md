# REoptLite Julia package
This package is currently under development and only has a subset of capabilities of the REopt Lite model used in the [REopt Lite API](https://github.com/NREL/REopt_Lite_API). For example, the Wind model, tiered electric utility tariffs, and piecewise linear cost curves are not yet modeled in this code. However this code is easier to use than the API (only dependencies are Julia and a solver) and has a novel model for uncertain outages.

Note: this package has been tested only with Julia 1.4 and 1.5 and may not be compatible with older versions.


## Uncertain outages
The full details of the model will be published in _Laws et al. 2021, Co-Optimizing Distributed Energy Resources for Grid-connected Benefits and Resilience Benefits Under Uncertain Grid Reliability, [Submitted]_. In brief, the model is set up to minimize the maximum expected outage cost (while minimizing the lifecycle cost of energy including utility tariff costs), where the maximum is taken over outage start times, and the expectation is taken over outage durations.

## Usage
Evaluating only `PV` and `Storage` requires a linear program solver. Adding a generator and/or multiple outages makes the problem mixed-integer linear, and thus requires a MILP solver. See https://jump.dev/JuMP.jl/stable/installation/ for a list of solvers. The REopt Lite package has been tested with `Xpress`, `Cbc` and `CPLEX`.
### Example
```
using Xpress
using JuMP
using REoptLite

m = Model(Xpress.Optimizer)
results = run_reopt(m, "path/to/scenario.json")
```
See the `test/scenarios` directory for examples of `scenario.json`.
