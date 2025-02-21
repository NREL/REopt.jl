# REopt® Julia package
REopt.jl is the core module of the [REopt® techno-economic decision support platform](https://www.nrel.gov/reopt/), developed by the National Renewable Energy Laboratory (NREL). REopt® stands for **R**enewable **E**nergy integration and **opt**imization. REopt.jl is used within the publicly-accessible and open-source [REopt API](https://github.com/NREL/REopt_API), and the publicly available [REopt Web Tool](https://reopt.nrel.gov/tool) calls the REopt API.

The REopt® techno-economic decision support platform is used by researchers to optimize energy systems for buildings, campuses, communities, microgrids, and more. REopt identifies the optimal mix of renewable energy, conventional generation, storage, and electrification technologies to meet cost savings, resilience, emissions reductions, and energy performance goals.

For more information about REopt.jl please see the Julia documentation:
<!-- [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://nrel.github.io/REopt.jl/stable) -->
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://nrel.github.io/REopt.jl/dev)


## Quick Start
Evaluating only `PV` and `Storage` requires a linear program solver. Adding a generator and/or multiple outages makes the problem mixed-integer linear, and thus requires a MILP solver. See https://jump.dev/JuMP.jl/stable/installation/ for a list of solvers. The REopt package has been tested with `Xpress`, `Cbc`, `HiGHS` and `CPLEX`.

Note that not all solvers support indicator constraints and special order sets (such as HiGHS), and so not all REopt problems can be solved with solvers lacking these capabilities.

### Example
```
using Xpress
using JuMP
using REopt

m = Model(Xpress.Optimizer)
results = run_reopt(m, "path/to/scenario.json")
```
See the `test/scenarios` directory for examples of `scenario.json`.

For more details, including installation instructions, see the [documentation](https://nrel.github.io/REopt.jl/dev).
