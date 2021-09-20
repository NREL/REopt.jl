# REoptLite Changelog

## v0.11.0
- add ElectricLoad.blended_doe_reference_names & blended_doe_reference_percents
- add ElectricLoad.monthly_totals_kwh builtin profile scaling
- add ElectricTariff inputs: `add_monthly_rates_to_urdb_rate`, `tou_energy_rates_per_kwh`, 
    `add_tou_energy_rates_to_urdb_rate`, `coincident_peak_load_charge_per_kw`, `coincident_peak_load_active_timesteps`
- handle multiple PV outputs

## v0.10.0
- add modeling capability for tiered rates (energy, TOU demand, and monthly demand charges)
    - all of these tiered rates require binaries, which are conditionally added to the model
- add modeling capability for lookback demand charges
- removed "_us_dollars" from all names and generally aligned names with API
- add more outputs from the API (eg. `initial_capital_costs`)
- add option to run Business As Usual scenario in parallel with optimal scenario (default is `true`)
- add incentives (and cost curves) to `Wind` and `Generator`
- fixed bug in URDB fixed charges
- renamed `outage_start(end)_timestep` to `outage_start(end)_time_step`

## v0.9.0
- `ElectricTariff.NEM` boolean is now determined by `ElectricUtility.net_metering_limit_kw` (true if limit > 0)
- add `ElectricUtility` inputs for `net_metering_limit_kw` and `interconnection_limit_kw`
- add binary choice for net metering vs. wholesale export
- add `ElectricTariff.export_rate_beyond_net_metering_limit` input (scalar or vector allowed)
- add `can_net_meter`, `can_wholesale`, `can_export_beyond_nem_limit` tech inputs (`PV`, `Wind`, `Generator`)

## v0.8.0
- add `Wind` module, relying on System Advisor Model Wind module for production factors and Wind Toolkit for resource data
- new `ElectricTariff` input options:
    - `urdb_utility_name` and `urdb_rate_name`
    - `blended_annual_energy_rate` and `blended_annual_demand_rate`
- add two capabilities that require binary variables:
    - tax, production, and capacity incentives for PV (compatible with any energy generation technology)
    - technology cost curve modeling capability
    - both of these capabilities are only used for the technologies that require them (based on input values), unlike the API which always models these capabilities (and therefore always includes the binary variables).
- `cost_per_kw[h]` input fields are now `installed_cost_per_kw[h]` to distinguish it from other costs like `om_cost_per_kw[h]`
- Financial input field refactored: `two_party_ownership` -> `third_party_ownership`
- `total_itc_pct` -> `federal_itc_pct` on technology inputs
- Three new tests: Wind, Blended Tariff and Complex Incentives (which aligns with API results)

## v0.7.3
##### bug fixes
- outage results processing would fail sometimes when an integer variable was not exact (e.g. 1.000000001)
- fixed `simulate_outages` for revised results formats (key names changed to align with the REopt Lite API)

## v0.7.2
#### Improvements
- add PV.prod_factor_series_kw input (can skip PVWatts call)
- add `run_mpc` capability, which dispatches DER for minimum energy cost over an arbitrary time horizon

## v0.7.1
##### bug fixes
- ElectricLoad.city default is empty string, must be filled in before annual_kwh look up

## v0.7.0
#### Improvements
- removed Storage.can_grid_export
- add optional integer constraint to prevent simultaneous export and import of power
- add warnings when adding integer variables
- add ability to add LinDistFlow constraints to multinode models
- no longer require `ElectricLoad.city` input (look up ASHRAE climate zone from lat/lon)
- compatible with Julia 1.6

## v0.6.0
#### Improvements
- add multi-node (site) capability for PV and Storage
- started documentation process using Github Pages and Documenter.jl
- restructured outputs to align with the input structure, for example top-level keys added for `ElectricTariff` and `PV` in the outputs

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
- added outage dispatch outputs and speed up their derivation
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
- add outage related outputs:
    - Generator_mg_kw
    - mg_Generator_upgrade_cost
    - mg_Generator_fuel_used
    - mg_PV_upgrade_cost
    - mg_storage_upgrade_cost
    - dvUnservedLoad array
    - max_outage_cost_per_outage_duration
- allow value_of_lost_load_per_kwh values to be subtype of Real (rather than only Real)
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
