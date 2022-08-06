# REopt.jl
*Renewable Energy Optimization and Integration*

!!! note
    This package is currently under development and not necessarily stable. It contains a subset of the [REopt API](https://github.com/NREL/REopt_API) capabilities.

## Installing
REopt evaluations for all system types **except GHP** can be performed using the following installation instructions from the Julia REPL:
```julia
using Pkg
Pkg.add("REopt")
```

### Additional package loading for GHP
GHP evaluations must load in the [`GhpGhx.jl`](https://github.com/NREL/GhpGhx.jl) package separately because it has a more [restrictive license](https://github.com/NREL/GhpGhx.jl/blob/main/LICENSE.md) and is not a registered Julia package.
```julia
Pkg.add("https://github.com/NREL/GhpGhx.jl")
using GhpGhx
```
