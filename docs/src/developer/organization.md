# File Organization

## data
Contains static input values such as the DoE Commercial Reference Building load profiles

## docs
Contains all of the files for constructing this package's documentation.

## src
All of the code necessary for this package.

### src/constraints
Mathematical model constraints organized by which high-level structures they primarily impact.

### src/core
The code that is central to this package. These files are used to build the inputs and the JuMP model. Some highlights:
- `scenario.jl` is the entry point for user's inputs. It uses many of the other files in the core directory to construct the high level inputs (such `electric_load.jl`, `financial.jl`, and `electric_tariff.jl`).
- `reopt_inputs.jl` uses the [Scenario](@ref) to construct the inputs necessary to build the JuMP model
- `reopt.jl` contains the methods for building and runnning the mathematical model

### src/lindistflow
Code for adding a LinDistFlow model to a multi-node REopt model.

### src/mpc
A Model Predictive Control implementation of REopt.

### src/outagesim
The outage simulator code, which calculates some resilience metrics such as the probability of surviving varying outage durations.

### src/results
All of the code for post-processing an optimized model and creating the results dictionary returned to the user.

### src/sam
System Advisor Model libraries used by this package for the Wind model.

## test
Built-in tests for several different solvers.
