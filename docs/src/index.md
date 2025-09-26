# REopt.jl
*Renewable Energy Optimization and Integration*

!!! note
    This package is used as the core model of the [REopt API](https://github.com/NREL/REopt_API) and the [REopt Web Tool](https://reopt.nrel.gov/tool). This package contains additional functionality and flexibility to run locally and customize.

## Installing
REopt evaluations for all system types except GHP (see below) can be performed using the following installation instructions from the package manager mode (`]`) of the Julia REPL:
```sh
(active_env) pkg> add REopt JuMP HiGHS
```

### Add NREL developer API key for PV, CST, and Wind
If you don't have an NREL developer network API key, [sign up here on https://developer.nrel.gov to get one (free)](https://developer.nrel.gov/signup); this is required to load PV and Wind resource profiles from PVWatts and the Wind Toolkit APIs from within REopt.jl.
Assign your API key to the expected environment variable:
```julia
ENV["NREL_DEVELOPER_API_KEY"]="your API key"
```
before running PV or Wind scenarios, and also assign your email to the expected environment variable as well before running CST scenarios: 
```julia
ENV["NREL_DEVELOPER_EMAIL"]="your contact email"
```

### Additional package loading for GHP
GHP evaluations must load in the [`GhpGhx.jl`](https://github.com/NREL/GhpGhx.jl) package separately because it has a more [restrictive license](https://github.com/NREL/GhpGhx.jl/blob/main/LICENSE.md) and is not a registered Julia package.

First add the GhpGhx.jl package to the project's dependencies from the package manager (`]`):
```sh
(active_env) pkg> add "https://github.com/NREL/GhpGhx.jl"
```

Then load in the package from the script where `run_reopt()` is called:
```julia
using GhpGhx
```