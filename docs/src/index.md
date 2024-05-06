# REopt.jl
*Renewable Energy Optimization and Integration*

!!! note
    This package is used as the core model of the [REopt API](https://github.com/NREL/REopt_API) and the [REopt Web Tool](https://reopt.nrel.gov/tool). This package contains additional functionality and flexibility to run locally and customize.

## Installing
REopt evaluations for all system types **except GHP** can be performed using the following installation instructions from the Julia REPL:
```julia
using Pkg
Pkg.add("REopt")
```

### Add NREL developer API key for PV and Wind
If you don't have an NREL developer network API key, sign up here to get one (free): https://developer.nrel.gov/signup/; this is required to load PV and Wind resource profiles from PVWatts and the Wind Toolkit APIs from within REopt.jl.
Assign your API key to the expected environment variable:
```julia
ENV["NREL_DEVELOPER_API_KEY"]="your API key"
```
before running PV or Wind scenarios.

### Additional package loading for GHP
GHP evaluations must load in the [`GhpGhx.jl`](https://github.com/NREL/GhpGhx.jl) package separately because it has a more [restrictive license](https://github.com/NREL/GhpGhx.jl/blob/main/LICENSE.md) and is not a registered Julia package.
```julia
Pkg.add("https://github.com/NREL/GhpGhx.jl")
using GhpGhx
```
