# REoptLite Changelog

## v0.5.3
#### Improvements
- compatible with Julia 1.5

## v0.5.2
#### bug fixes
- outage_simulator.jl had bug with summing over empty `Any[]`

#### Improvements
- add optional `microgrid_only` arg to simulate_outages

## v0.5.1
#### Improvements
- added outage dispatch outputs and sped up their derivation
- removed redundant generator minimum turn down constraint

## v0.5.0
#### bug fixes
- handle missing input key for `year_one_soc_series_pct` in `outage_simulator` 
- remove erroneous `total_unserved_load = 0` output
- `dvUnservedLoad` definition was allowing microgrid production to storage and curtailment to be double counted towards meeting critical load

#### Improvements
- add `unserved_load_per_outage` output

## v0.4.1
#### bug fixes
- removed `total_unserved_load` output because it can take hours to generate and can error out when outage indices are not consecutive
#### Improvements
- add @info for time spent processing results

## v0.4.0
#### Improvements
- add `simulate_outages` function (similar to REopt Lite API outage simulator)
- removed MutableArithmetics package from Project.toml (since JuMP now has method for `value(::MutableArithmetics.Zero)`)
- added outage related outputs:
    - Generator_mg_kw
    - mg_Generator_upgrade_cost
    - mg_Generator_fuel_used
    - mg_PV_upgrade_cost
    - mg_storage_upgrade_cost
    - dvUnservedLoad array
    - max_outage_cost_per_outage_duration
- allow VoLL values to be subtype of Real (rather than only Real)
- add `run_reopt` method for scenario Dict

## v0.3.0
#### Improvements
- add separate decision variables and constraints for microgrid tech capacities
    - new Site input `mg_tech_sizes_equal_grid_sizes` (boolean), when `false` the microgrid tech capacities are constrained to be <= the grid connected tech capacities
#### bug fixes
- allow non-integer `outage_probabilities`
- correct `total_unserved_load` output
- don't `add_min_hours_crit_ld_met_constraint` unless `min_resil_timesteps <= length(elecutil.outage_timesteps)`

## v0.2.0
#### Improvements
- add support for custom ElectricLoad `loads_kw` input
- include existing capacity in microgrid upgrade cost
    - previously only had to pay to upgrade new capacity
- implement ElectricLoad `loads_kw_is_net` and `critical_loads_kw_is_net`
    - add existing PV production to raw load profile if `true`
- add `min_resil_timesteps` input and optional constraint for minimum timesteps that critical load must be met in every outage
#### bug fixes
- enforce storage cannot grid charge

## v0.1.1 Fix build.jl
deps/build.jl had a relative path dependency, fixed with an absolute path.

## v0.1.0 Initial release
This package is currently under development and only has a subset of capabilities of the REopt Lite model used in the REopt Lite API. For example, the Wind model, tiered electric utility tariffs, and piecewise linear cost curves are not yet modeled in this code. However this code is easier to use than the API (only dependencies are Julia and a solver) and has a novel model for uncertain outages.
