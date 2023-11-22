# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Guidelines
- When making a Pull Request into `develop` start a new double-hash header for "Develop - YYYY-MM-DD"
- When making a Pull Request into `master` change "Develop" to the next version number

### Formatting
- Use **bold** markup for field and model names (i.e. **outage_start_time_step**)
- Use `code` markup for  REopt-specific file names, classes and endpoints (e.g. `src/REopt.jl`)
- Use _italic_ for code terms (i.e. _list_)
- Prepend change with tag(s) directing where it is in the repository:  
`src`,`constraints`,`*.jl`

Classify the change according to the following categories:
    
    ### Added
    ### Changed
    ### Fixed
    ### Deprecated
    ### Removed

## v0.38.1
### Fixed
- Fix CHP standby charge modeling - bad reference to pwf_e
- Avoid breaking backward compatibility with type declaration of (global) const urdb_api_key

## v0.38.0
### Changed
- Require NREL Developer API Key set as ENV["NREL_DEVELOPER_API_KEY"] = 'your API key' for PVWatts and Wind Toolkit

## v0.37.5
### Fixed
- Fixed AVERT emissions profiles for NOx. Were previously the same as the SO2 profiles. AVERT emissions profiles are currently generated from AVERT v3.2 https://www.epa.gov/avert/download-avert. See REopt User Manual for more information.
- Fix setting of equal demand tiers in scrub_urdb_demand_tiers!, which was previously causing an error. 
- When calling REopt.jl from a python environment using PyJulia and PyCall, some urdb_response fields get converted from a list-of-lists to a matrix type, when REopt.jl expects an array type. This fix adds checks on the type for two urdb_response fields and converts them to an array if needed.
- Update the outages dispatch results to align with CHP availability during outages

## v0.37.4
### Fixed
- Include `year` in creation of electric-only CHP for unavailability profile

## v0.37.3
### Changed
- Ignore `CHP` unavailability during stochastic, multiple outages; this is consistent with deterministic single outage

## v0.37.2
### Changed
- Do not enforce `CHP.min_turn_down_fraction` for outages

## v0.37.1
### Fixed
- CHP-only for multiple/stochastic outages
- Allow negative fuel_burn and thermal_prod intercepts for CPH
- Correct after_tax CHP results

## v0.37.0
### Added
- Added Bool attribute `is_electric_only` to CHP; if true, default installed and O&M costs are reduced by 25% and, for the reciprocating engine and combustion turbine prime movers, the federal ITC fraction is reduced to zero.
- Las Vegas CRB data was missing from ElectricLoad, but the climate_cities.shp file does not distinguish between Las Angeles and Las Vegas
### Changed
- Update `CHP.size_class` after heuristic size is determined based on size_class=0 guess (not input)
### Fixed
- Use the user-input `ExistingBoiler.efficiency` value for converting fuel input to thermal to preserve annual fuel energy input
- Fix heating loads monthly_mmbtu and addressable_load_fraction handling (type issues mostly)
- Bug fix for user-supplied 8760 WHL rates with tiered energy rate

## v0.36.0
### Changed
- Changed default values by prime mover for CHP technologies in `data/chp/chp_defaults.json`.  See user manual for details by prime mover and size class.
- Updated the package dependencies to be compatible with recent changes to HiGHS (for testing) and MathOptInterface
### Fixed
- The present worth factor for fuel (pwf_fuel) was not properly multiplying for lifecycle fuel costs

## v0.35.1
### Fixed
- Add GHP to proforma metrics for when GHP is evaluated (should have been there)
### Added
- Add different BAU outputs for heating and cooling systems

## v0.35.0
### Changed
- ANNUAL UPDATE TO DEFAULT VALUES. Changes outlined below with (old value) --> (new value). See user manual for references. 
  - Owner Discount rate, nominal (%): : **Financial** **owner_discount_rate_fraction** 0.0564	--> 0.0638
  - Offtaker Discount rate, nominal (%): **Financial**  **offtaker_discount_rate_fraction** 0.0564 --> 0.0638
  - Electricity cost escalation rate, nominal (%): **Financial** **elec_cost_escalation_rate_fraction** 0.019	--> 0.017
  - Existing boiler fuel cost escalation rate, nominal (%): **Financial**  **existing_boiler_fuel_cost_escalation_rate_fraction**	0.034	--> 0.015
  - Boiler fuel cost escalation rate, nominal (%): **Financial** **boiler_fuel_cost_escalation_rate_fraction**	0.034	--> 0.015
  - CHP fuel cost escalation rate, nominal (%): **Financial**  **chp_fuel_cost_escalation_rate_fraction**	0.034	--> 0.015
  - Generator fuel cost escalation rate, nominal (%): **Financial**  **generator_fuel_cost_escalation_rate_fraction**	0.027	--> 0.012
  - Array tilt – Ground mount, Fixed: **PV** **tilt** latitude	--> 20
  - O&M cost ($/kW/year): **PV** **om_cost_per_kw**	17	--> 18
  - System capital cost ($/kW): **PV** **installed_cost_per_kw**	1592	--> 1790
  - Energy capacity cost ($/kWh): **ElectricStorage** **installed_cost_per_kwh**	388	--> 455
  - Power capacity cost ($/kW): **ElectricStorage**	**installed_cost_per_kw**	775	--> 910
  - Energy capacity replacement cost ($/kWh): **ElectricStorage** **replace_cost_per_kwh**	220	--> 318
  - Power capacity replacement cost ($/kW): **ElectricStorage**	**replace_cost_per_kw**	440	--> 715
  - Fuel burn rate by generator capacity (gal/kWh): **Generator** **fuel_slope_gal_per_kwh**	0.076	--> removed and replaced with full and half-load efficiencies
  - Electric efficiency at 100% load (% HHV-basis): **Generator** **electric_efficiency_full_load**	N/A - new input	--> 0.322
  - Electric efficiency at 50% load (% HHV-basis): **Generator** **electric_efficiency_half_load**	N/A - new input	--> 0.322
  - Generator fuel higher heating value (HHV): **Generator** **fuel_higher_heating_value_kwh_per_gal**	N/A - new input	--> 40.7
  - System capital cost ($/kW): **Generator**  **installed_cost_per_kw** 500	--> $650 if the generator only runs during outages; $800 if it is allowed to run parallel with the grid; $880 for off-grid
  - Fixed O&M ($/kW/yr): **Generator** **om_cost_per_kw** Grid connected: 10 Off-grid: 20 --> Grid connected: 20 Off-grid: 10
  - System capital cost ($/kW) by Class: **Wind** **size_class_to_installed_cost**	residential - 5675 commercial - 4300 medium - 2766 large - 2239 --> residential - 6339 commercial - 4760 medium - 3137 large - 2386
  - O&M cost ($/kW/year): **Wind** **om_cost_per_kw** 35 --> 36
 
## v0.34.0
### Added
- Ability to run hybrid GHX sizing using **GhpGhx.jl** (automatic and fractional sizing)
- Added financial inputs for **GHP** and updated objective and results to reflect these changes
- Added central plant **GHP**
### Fixed
- Fix output of `get_tier_with_lowest_energy_rate(u::URDBrate)` to return an index and not cartesian coordinates for multi-tier energy rates.
- Updated **GHP** cost curve calculations so incentives apply to all GHP components
### Changed
- If a `REoptInputs` object solves with termination status infeasible, altert user and return a dictionary insteadof JuMP model

## v0.33.0
### Added
- Functionality to evaluate scenarios with Wind can in the ERP (`backup_reliability`)
- Dispatch data for outages: Wind, ElectricStorage SOC, and critical load
### Fixed
- Fix `backup_reliability_reopt_inputs(d, p, r)` so doesn't ignore `CHP` from REopt scenario
- In `backup_reliability_reopt_inputs(d, p, r)`, get `Generator` and `CHP` fuel related values from REopt results _Dict_ d and `REoptInputs` _struct_ p, unless the user overrides the REopt results by providing **generator_size_kw**
- Remove use of non-existent **tech_upgraded** `Outages` outputs, using **tech_microgrid_size_kw** instead
- Added missing **electric_storage_microgrid_upgraded** to `Outages` results
- Fix bug causing _InexactError_ in `num_battery_bins_default`
- Update docstrings in `backup_reliability.jl`
- Avoid supply > critical load during outages by changing load balance to ==
### Changed
- Updated REopt license
- Changed `backup_reliability` results key from **fuel_outage_survival_final_time_step** to **fuel_survival_final_time_step** for consistency with other keys

## v0.32.7
### Fixed
- Bugs in EASIUR health cost calcs
- Type handling for CoolingLoad monthly_tonhour input

## v0.32.6
### Changed
- Required **fuel_cost_per_mmbtu** for modeling **Boiler** tech, otherwise throw a handled error.
### Fixed
- Additional **SteamTurbine** defaults processing updates and bug fixes

## v0.32.5
### Changed
- Updated `get_existing_chiller_cop` function to accept scalar values instead of vectors to allow for faster API transactions.
- Refactored `backup_reliability.jl` to enable easier development: added conversion of all scalar generator inputs to vectors in `dictkeys_to_symbols` and reduced each functions with two versions (one with scalar and one with vector generator arguments) to a single version
- Simplify generator sizing logic in function `backup_reliability_reopt_inputs` (if user sets `generator_size_kw` or `num_generators`to 0, don't override based on REopt solution) and add a validation error
### Fixed
- Steamturbine defaults processing
- simulated_load monthly values processing
- Fixed incorrect name when accessing result field `Outages` **generator_microgrid_size_kw** in `outag_simulator.jl`

## v0.32.4
### Changed
- Consolidated PVWatts API calls to 1 call (previously 3 separate calls existed). API call occurs in `src/core/utils.jl/call_pvwatts_api()`. This function is called for PV in `src/core/production_factor.jl/get_production_factor(PV)` and for GHP in `src/core/scenario.jl`. If GHP and PV are evaluated together, the GHP PVWatts call for ambient temperature is also used to assign the pv.production_factor_series in Scenario.jl so that the PVWatts API does not get called again downstream in `get_production_factor(PV)`.  
- In `src/core/utils.jl/call_pvwatts_api()`, updated NSRDB bounds used in PVWatts query (now includes southern New Zealand)
- Updated PV Watts version from v6 to v8. PVWatts V8 updates the weather data to 2020 TMY data from the NREL NSRDB for locations covered by the database. (The NSRDB weather data used in PVWatts V6 is from around 2015.) See other differences at https://developer.nrel.gov/docs/solar/pvwatts/.
- Made PV struct mutable: This allows for assigning pv.production_factor_series when calling PVWatts for GHP, to avoid a extra PVWatts calls later.
- Changed unit test expected values due to update to PVWatts v8, which slightly changed expected PV production factors.
- Changed **fuel_avail_gal** default to 1e9 for on-grid scenarios (same as off-grid)
### Fixed
- Issue with using a leap year with a URDB rate - the URDB rate was creating energy_rate of length 8784 instead of intended 8760
- Don't double add adjustments to urdb rates with non-standard units
- Corrected `Generator` **installed_cost_per_kw** from 500 to 650 if **only_runs_during_grid_outage** is _true_ or 800 if _false_
- Corrected `SteamTurbine` defaults population from `get_steam_turbine_defaults_size_class()`

## v0.32.3
### Fixed
- Calculate **num_battery_bins** default in `backup_reliability.jl` based on battery duration to prevent significant discretization error (and add test)
- Account for battery (dis)charge efficiency after capping power in/out in `battery_bin_shift()`
- Remove _try_ _catch_ in `backup_reliability(d::Dict, p::REoptInputs, r::Dict)` so can see where error was thrown

## v0.32.2
### Fixed
- Fixed bug in multiple PVs pv_to_location dictionary creation. 
- Fixed bug in reporting of grid purchase results when multiple energy tiers are present.
- Fixed bug in TOU demand charge calculation when multiple demand tiers are present.

## v0.32.1
### Fixed
- In `backup_reliability.jl`:
    - Check if generator input is a Vector instead of has length greater than 1
    - Correct calculation of battery SOC adjustment in `fuel_use()` function
    - Correct outage time step survival condition in `fuel_use()` function
- Add test to ensure `backup_reliability()` gives the same results for equivalent scenarios (1. battery only and 2. battery plus generator with no fuel) and that the survival probability decreases monotonically with outage duration
- Add test to ensure `backup_reliability()` gives the same results as `simulate_outages()` when operational availability inputs are 1, probability of failure to run is 0, and mean time to failure is a very large number.

## v0.32.0
### Fixed
- Fixed calculation of `wind_kw_ac_hourly` in `outagesim/outage_simulator.jl`
- Add  a test of multiple outages that includes wind
- Add a timeout to PVWatts API call so that if it does not connect within 10 seconds, it will retry. It seems to always work on the first retry.

## v0.31.0
### Added
- Created and exported easiur_data function (returns health emissions costs and escalations) for the API to be able to call for it's easiur_costs endpoint
- Added docstrings for easiur_data and emissions_profiles

## v0.30.0
### Added
- `Generator` input **fuel_higher_heating_value_kwh_per_gal**, which defaults to the constant KWH_PER_GAL_DIESEL
### Changed
- Added more description to **production_factor_series inputs**
### Fixed
- Fixed spelling of degradation_fraction
- use push! instead of append() for array in core/cost_curve.jl
- Fixed calculation of batt_roundtrip_efficiency in outage_simulator.jl

## v0.29.0
### Added
- Add `CHP` `FuelUsed` and `FuelCost` modeling/tracking for stochastic/multi-outages
- Add `CHP` outputs for stochastic/multi-outages
### Changed
- Made outages output names not dynamic to allow integration into API
- Add missing units to outages results field names: **unserved_load_series_kw**, **unserved_load_per_outage_kwh**, **generator_fuel_used_per_outage_gal**
- Default `Financial` field **microgrid_upgrade_cost_fraction** to 0
- Add conditional logic to make `CHP.min_allowable_kw` 25% of `max_kw` if there is a conflicting relationship 
- Iterate on calculating `CHP` heuristic size based on average heating load which is also used to set `max_kw` if not given: once `size_class` is determined, recalculate using the efficiency numbers for that `size_class`.
### Fixed
- Fix non-handling of cost-curve/segmented techs in stochastic outages
- Fix issues with `simulated_load.jl` monthly heating energy input to return the heating load profile

## v0.28.1
### Added
- `emissions_profiles` function, exported for external use as an endpoint in REopt_API for the webtool/UI

## v0.28.0
### Changed 
- Changed Financial **breakeven_cost_of_emissions_reduction_per_tonnes_CO2** to **breakeven_cost_of_emissions_reduction_per_tonne_CO2**
- Changed `CHP.size_class` to start at 0 instead of 1, consistent with the API, and 0 represents the average of all `size_class`s
- Change `CHP.max_kw` to be based on either the heuristic sizing from average heating load (if heating) or peak electric load (if no heating, aka Prime Generator in the UI)
  - The "big_number" for `max_kw` was causing the model to take forever to solve and some erroneous behavior; this is also consistent with the API to limit max_kw to a reasonable number
### Added 
- Added previously missing Financial BAU outputs: **lifecycle_om_costs_before_tax**, **lifecycle_om_costs_after_tax**, **year_one_om_costs_before_tax**
### Fixed
- Fixed if statement to determing ElectricLoad "year" from && to ||, so that defaults to 2017 if any CRB input is used
    
## v0.27.0
### Added
- Energy Resilience Performance tool: capability to model limited reliability of backup generators and RE, and calculate survival probability metrics during power outages for a DER scenario
- Exported `backup_reliability` function to run the reliability based calculations
### Changed
- Changed `Generator` inputs **fuel_slope_gal_per_kwh** and **fuel_intercept_gal_per_hr** to **electric_efficiency_full_load** and **electric_efficiency_half_load** to represent the same fuel burn curve in a different way consistent with `CHP`

## v0.26.0
### Added 
- Added `has_stacktrace` boolean which is returned with error messages and indicates if error is of type which contains stacktrace
- Constraint on wind sizing based on Site.land_acres
- New Wind input **acres_per_kw**, defaults to 0.03
- Descriptions/help text for many inputs and outputs
- Add and modify the `GHP` results to align with the existing/expected results from the v2 REopt_API
- Add `CSV` and `DataFrames` packages to REopt.jl dependencies 
### Changed
- Update REopt.jl environment to Julia v1.8
- Changed default **year** in ElectricLoad to be 2017 if using a CRB model and 2022 otherwise. 
- Removed default year in URDBrate() functions, since year is always supplied to this function.
- In `scenario.jl`, `change heating_thermal_load_reduction_with_ghp_kw` to `space_heating_thermal_load_reduction_with_ghp_kw` to be more explicit
- Round Hot and Cold TES size result to 0 digits
- Use CoolProp to get water properties for Hot and Cold TES based on average of temperature inputs
### Fixed
- `Wind` evaluations with BAU - was temporarily broken because of an unconverted **year_one** -> **annual** expected name
- Fixed calculation of **year_one_coincident_peak_cost_before_tax** in `ElectricTariff` results to correctly calculate before-tax value. Previously, the after-tax value was being calculated for this field instead.
- Fixed `outage_simulator` to work with sub-hourly outage simulation scenarios
- Fixed a bug which threw an error when providing time-series thermal load inputs in a scenario inputs .json.
- Fixed calculation of ["Financial"]["lifecycle_om_costs_before_tax_bau"] (was previously showing after tax result)
- Added **bau_annual_emissions_tonnes_SO2** to the bau_outputs dict in results.jl and removed duplicate **bau_annual_emissions_tonnes_NOx** result
### Removed
- Removed duplicate **thermal_production_hot_water_or_steam** field from the absorption chiller defaults response dictionary. 

## v0.25.0
### Added
- multi-node MPC modeling capability
- more MPC outputs (e.g. Costs, ElectricStorage.to_load_series_kw)
- throw error if outage_durations and outage_probabilities not the same length
- throw error if length of outage_probabilities is >= 1 and sum of outage_probabilities is not equal to 1
- small incentive to minimize unserved load in each outage, not just the max over outage start times (makes expected outage results more realist and fixes same inputs giving different results)
- add `Outages` output **generator_fuel_used_per_outage** which is the sum over backup generators
### Changed
- remove _series from non-timeseries outage output names
- make the use of _ in multiple outages output names consistent
- updates multiple outage test values that changed due to fixing timestep bug
- Updated the following default values:
   - PV, Wind, Storage, CHP, GHP, Hot Water Storage, Cold Water Storage, Electric Storage: **federal_itc_fraction(PV,Wind, CHP,GHP)** and **total_itc_fraction(Hot Water Storage, Cold Water Storage, Electric Storage)** to 0.3 (30%)
   - PV, Wind, Storage, CHP, GHP, Hot Water Storage, Cold Water Storage, Electric Storage: **macrs_bonus_fraction** to 0.8 (80%)
   - Hot Water Storage and Cold Water Storage: **macrs_itc_reduction** to 0.5 (50%)
   - Hot Water Storage and Cold Water Storage: **macrs_option_years** to 7 years
### Fixed
- PV results for all multi-node scenarios
- MPC objective definition w/o ElectricStorage
- fixed mulitple outages timestep off-by-one bug
### Removed 
- Wind ITC no longer determined based on size class. Removed all size class dependencies from wind.jl

## v0.24.0
### Changed
- Major name change overall for outputs/results. Changed energy-related outputs with "year_one" in name to "annual" to reflect that they are actually average annual output values. Changed any "average_annual" naming to "annual" to simplify. Changed `to_tes` and `to_battery` outputs to `to_storage` for consistency
### Added 
- Added **thermal_production_series_mmbtu_per_hour** to CHP results. 
### Removed 
- Removed `Wind` and `Generator` outputs **year_one_energy_produced_kwh** since these techs do not include degradation

## v0.23.0
### Added
- Add **REoptLogger** type of global logger with a standard out to the console and to a dictionary
    - Instantiate `logREopt` as the global logger in `__init()__` function call as a global variable
    - Handle Warn or Error logs to save them along with information on where they occurred
    - Try-catch `core/reopt.jl -> run_reopt()` functions. Process any errors when catching the error.
    - Add Warnings and Errors from `logREopt` to results dictionary. If error is unhandled in REopt, include a stacktrace
    - Add a `status` of `error` to results for consistency
    - Ensure all error text is returned as strings for proper handling in the API
- Add `handle_errors(e::E, stacktrace::V) where {E <: Exception, V <: Vector}` and `handle_errors()` to `core/reopt.jl` to include info, warn and errors from REopt input data processing, optimization, and results processing in the returned dictionary.
- Tests for user-inputs of `ElectricTariff` `demand_lookback_months` and `demand_lookback_range` 
### Changed
- `core/reopt.jl` added try-catch statements to call `handle_errors()` when there is a REopt error (handled or unhandled) and return it to the requestor/user.
### Fixed
- URDB lookback was not incorporated based on the descriptions of how the 3 lookback variables should be entered in the code. Modified `parse_urdb_lookback_charges` function to correct.
- TOU demand for 15-min load was only looking at the first 8760 timesteps.
- Tiered energy rates jsons generated by the webtool errored and could not run.
- Aligned lookback parameter names from URDB with API

## v0.22.0
### Added
- Simulated load function which mimicks the REopt_API /simulated_load endpoint for getting commercial reference building load data from annual or monthly energy data, or blended/hybrid buildings
- `AbsorptionChiller` default values for costs and thermal coefficient of performance (which depend on maximum cooling load and heat transfer medium)
### Changed
- Pruned the unnecessary chp_defaults data that were either zeros or not dependent on `prime_mover` or `size_class`, and reorganized the CHP struct.

## v0.21.0
### Changed
For `CHP` and `SteamTurbine`, the `prime_mover` and/or `size_class` is chosen (if not input) based on the average heating load and the type of heating load (hot water or steam).
 - This logic replicates the current REopt webtool behavior which was implemented based on CHP industry experts, effectively syncing the webtool and the REopt.jl/API behavior.
 - This makes `prime_mover` **NOT** a required input and avoids a lot of other required inputs if `prime_mover` is not input.
 - The two functions made for `CHP` and `SteamTurbine` are exported in `REopt.jl` so they can be exposed in the API for communication with the webtool (or other API users).
### Removed 
`ExistingBoiler.production_type_by_chp_prime_mover` because that is no longer consistent with the logic added above.
 - The logic from 1. is such that `ExistingBoiler.production_type` determines the `CHP.prime_mover` if not specified, not the other way around.
 - If `ExistingBoiler.production_type` is not input, `hot_water` is used as the default.

## v0.20.1
### Added
- `CoolingLoad` time series and annual summary data to results
- `HeatingLoad` time series and annual summary data to results

## v0.20.0
### Added
- `Boiler` tech from the REopt_API (known as NewBoiler in API)
- `SteamTurbine` tech from the REopt_API
### Changed
- Made some modifications to thermal tech results to be consistent with naming conventions of REopt.jl
### Fixed
- Bug for scalar `ElectricTariff.wholesale_rate`
- Bug in which CHP could not charge Hot TES

## v0.19.0
### Changed
The following name changes were made: 
- Change "pct" to "rate_fraction" for "discount", "escalation", names containing "tax_pct" (financial terms)
- Change "pct" to "fraction" for all other variable names (e.g., "min_soc", "min_turndown_")
- Change `prod_factor_series` to `production_factor_series` and rename some internal methods and variables to match
- Change four (4) CHP input field names to spell out `electric` (from `elec`) and `efficiency` (from `effic`) for electric and thermal efficiencies
### Added
- Add schedule-based `FlatLoad`s which take the annual or monthly energy input and create a load profile based on the specified type of schedule. The load is "flat" (the same) for all hours within the chosen schedule.
- Add `addressable_load_fraction` inputs for `SpaceHeatingLoad` and `DomesticHotWaterLoad` which effectively ignores a portion of the entered loads. These inputs can be scalars (applied to all time steps of the year), monthly (applied to the timesteps of each month), or of length 8760 * `time_steps_per_hour`.
- Add a validation error for cooling in the case that the cooling electric load is greater than the total electric load.
  
## v0.18.1
### Removed
- **include_climate_in_objective**, **pwf_emissions_cost_CO2_grid**, and **pwf_emissions_cost_CO2_onsite** unnecessarily included in Site results

## v0.18.0
### Added
- Add geothermal heat pump (`GHP`), also known as ground-source heat pump (GSHP), to the REopt model for serving heating and cooling loads (typically the benefits include electrifying the heating load and improving the efficiency of cooling).
    - The unregistered `GhpGhx` package (https://github.com/NREL/GhpGhx.jl) is a "conditional" dependency of REopt by using the Requires.jl package, and this package sizes the ground heat exchanger (GHE) and gets the hourly electric consumption of the `GHP` for the specified heating and cooling loads that it serves.
    - The `GhpGhx` module calls for sizing the GHE can only be done if you first "add https://github.com/NREL/GhpGhx.jl" to the environment and then load the package by "using GhpGhx" before running REopt with `GHP`.
    - The `GHP` size and dispatch of the different `GHP` options is pre-determined by the `GhpGhx` package, so the REopt model just chooses one or none of the `GHP` options with a binary decision variable.
### Changed
- Change default value for `wind.jl` **operating_reserve_required_pct** from 0.1 to 0.5 (only applicable when **off_grid_flag**=_True_.)
- allow user to specify emissions_region in ElectricUtility, which is used instead of lat/long to look up AVERT data if emissions factors aren't provided by the user
- Updated results keys in `results/absorption_chiller.jl`
### Fixed
- Add **wholesale_rate** and **emissions_factor_series_lb_\<pollutant\>_per_kwh** inputs to the list of inputs that `dictkeys_tosymbols()` tries to convert to type _Array{Real}_. Due to serialization, when list inputs come from the API, they are of type _Array{Any}_ so must be converted to match type required by the constructors they are passed to.
- Fixed bug in calcuation of power delivered to cold thermal storage by the electric chiller in `results/existing_chiller.jl`.

## v0.17.0
### Added
- Emissions
    - add emissions factors for CO2, NOx, SO2, and PM25 to inputs of all fuel burning technologies
    - add emissions factor series for CO2, NOx, SO2, and PM25 to `ElectricUtility` inputs and use [AVERT v3.2](https://www.epa.gov/avert/download-avert) (2021 data) if not provided
    - add `include_climate_in_objective` and `include_health_in_objective` to `Settings` inputs
    - constrain CO2 emissions based on `CO2_emissions_reduction_min_pct`, `CO2_emissions_reduction_max_pct`, and `include_exported_elec_emissions_in_total` added to `Site` inputs
    - add emissions costs to `Financial` inputs and use EASIUR data for NOx, SO2, and PM25 if not provided
    - report emissions and their cost in `Site` (on-site and total) and `ElectricUtility` (grid) results
    - calculate `breakeven_cost_of_emissions_reduction_per_tonnes_CO2` for `Financial` results
- Renewable energy percentage
    - calculate renewable energy percentage (electric only and total) and add to `Site` results
    - add `renewable_electricity_min_pct`, `renewable_electricity_max_pct`, and `include_exported_renewable_electricity_in_total` to `Site` inputs
    - add `fuel_renewable_energy_pct` input for all fuel burning technologies
    - constrain renewable electricity percentage based on user inputs
- Add "Emissions and Renewable Energy Percent" testset
### Changed
- Allow Wind tech to be included when `off_grid_flag` is true
- Add `operating_reserve_required_pct` to Wind struct and incorporate wind into operating reserve constraints
- Add hot, cold TES results for MPC model
- Update documentation and add `docs/devdeploy.jl` to locally host the REopt.jl documentation 
- Make `ExistingBoiler` `fuel_cost_per_mmbtu` a required input
- In `production_factor.jl`, include lat-long coordinates if-statement to determine whether the "nsrdb" dataset should be used in call to PVWatts. Accounts for recent updates to NSRDB data used by PVWatts (v6). If outside of NSRDB range, use "intl" (international) dataset.
- Don't trigger GitHub 'Run test' workflow on a push that only changes README.md and/or CHANGELOG.md
- Avoid triggering duplicate GitHub workflows. When pushing to a branch that's in a PR, only trigger tests on the push not on the PR sync also.
### Fixed
- Bug fix to constrain dvCurtail in `time_steps_without_grid`
- Bug fix to report accurate wind ["year_one_to_load_series_kw"] in results/wind.jl (was previously not accounting for curtailed wind)

## v0.16.2
### Changed
- Update PV defaults to tilt=10 for rooftop, tilt = abs(lat) for ground mount, azimuth = 180 for northern lats, azimuth = 0 for southern lats.
### Fixed
- bug fix for Generator inputs to allow for time_steps_per_hour > 1
- change various `Float64` types to `Real` to allow integers too

## v0.16.1
### Fixed
- bug fix for outage simulator when `microgrid_only=true`

## v0.16.0
### Added
Allows users to model "off-grid" systems as a year-long outage: 
- add flag to "turn on" off-grid modeling `Settings.off_grid_flag` 
- when `off_grid_flag` is "true", adjust default values in core/ `electric_storage`, `electric_load`, `financial`, `generator`, `pv` 
- add operating reserve requirement inputs, outputs, and constraints based on load and PV generation 
- add minimum load met percent input and constraint
- add generator replacement year and cost (for off-grid and on-grid) 
- add off-grid additional annual costs (tax deductible) and upfront capital costs (depreciable via straight line depreciation)
### Changed
Name changes: 
- consistently append `_before_tax` and `_after_tax` to results names 
- change all instances of `timestep` to `time_step` and `timesteps` to `time_steps`
Other changes:
- report previously missing lcc breakdown components, all reported in `results/financial.jl`  
- change variable types from Float to Real to allow users to enter Ints (where applicable)
- `year_one_coincident_peak_cost_after_tax` is now correctly multiplied by `(1 - p.s.financial.offtaker_tax_pct)`

## v0.15.2
### Fixed
- bug fix for 15 & 30 minute electric, heating, and cooling loads
- bug fix for URDB fixed charges
- bug fix for default `Wind` `installed_cost_per_kw` and `federal_itc_pct`

## v0.15.1
### Added
- add `AbsorptionChiller` technology
- add `ElectricStorage.minimum_avg_soc_fraction` input and constraint

## v0.15.0
### Fixed
- bug fix in outage_simulator
### Changed
- allow Real Generator inputs (not just Float64)
- add "_series" to "Outages" outputs that are arrays [breaking]

## v0.14.0
### Changed
- update default values from v2 of API [breaking]
### Added
- add ElectricStorage degradation accounting and maintenance strategies
- finish cooling loads

## v0.13.0
### Added
- add FlexibleHVAC model (still testing)
- start thermal energy storage modeling
- add `ExistingBoiler` and `ExistingChiller`
- add `MPCLimits` inputs:
    - `grid_draw_limit_kw_by_time_step`
    - `export_limit_kw_by_time_step`
### Changed
- refactor `Storage` as `ElectricStorage`
### Fixed
- fix bugs for time_steps_per_hour != 1


## v0.12.4
### Removed
- rm "Lite" from docs
### Changed
- prioritize `urdb_response` over `urdb_label` in `ElectricTariff`

## v0.12.3
### Added
- add utils for PVwatts: `get_ambient_temperature` and `get_pvwatts_prodfactor`

## v0.12.2
### Added
- add CHP technology, including supplementary firing
- add URDB "sell" value from `energyratestructure` to wholesale rate
- update docs
### Changed
- allow annual or monthly energy rate w/o demand rate
- allow integer latitude/longitude

## v0.12.1
### Added
- add ExistingBoiler and CRB heating loads

## v0.12.0
### Changed
- change all output keys starting with "total_" or "net_" to "lifecycle_" (except "net_present_cost")
- update pv results for single PV in an array
### Fixed
- bug fix in urdb.jl when rate_name not found

## v0.11.0
### Added
- add ElectricLoad.blended_doe_reference_names & blended_doe_reference_percents
- add ElectricLoad.monthly_totals_kwh builtin profile scaling
- add ElectricTariff inputs: `add_monthly_rates_to_urdb_rate`, `tou_energy_rates_per_kwh`, 
    `add_tou_energy_rates_to_urdb_rate`, `coincident_peak_load_charge_per_kw`, `coincident_peak_load_active_time_steps`
### Fixed
- handle multiple PV outputs

## v0.10.0
### Added
- add modeling capability for tiered rates (energy, TOU demand, and monthly demand charges)
    - all of these tiered rates require binaries, which are conditionally added to the model
- add modeling capability for lookback demand charges
- add more outputs from the API (eg. `initial_capital_costs`)
- add option to run Business As Usual scenario in parallel with optimal scenario (default is `true`)
- add incentives (and cost curves) to `Wind` and `Generator`
### Changed
- removed "_us_dollars" from all names and generally aligned names with API
- renamed `outage_start(end)_time_step` to `outage_start(end)_time_step`
### Fixed
- fixed bug in URDB fixed charges

## v0.9.0
### Changed
- `ElectricTariff.NEM` boolean is now determined by `ElectricUtility.net_metering_limit_kw` (true if limit > 0)
### Added
- add `ElectricUtility` inputs for `net_metering_limit_kw` and `interconnection_limit_kw`
- add binary choice for net metering vs. wholesale export
- add `ElectricTariff.export_rate_beyond_net_metering_limit` input (scalar or vector allowed)
- add `can_net_meter`, `can_wholesale`, `can_export_beyond_nem_limit` tech inputs (`PV`, `Wind`, `Generator`)

## v0.8.0
### Added
- add `Wind` module, relying on System Advisor Model Wind module for production factors and Wind Toolkit for resource data
- new `ElectricTariff` input options:
    - `urdb_utility_name` and `urdb_rate_name`
    - `blended_annual_energy_rate` and `blended_annual_demand_rate`
- add two capabilities that require binary variables:
    - tax, production, and capacity incentives for PV (compatible with any energy generation technology)
    - technology cost curve modeling capability
    - both of these capabilities are only used for the technologies that require them (based on input values), unlike the API which always models these capabilities (and therefore always includes the binary variables).
- Three new tests: Wind, Blended Tariff and Complex Incentives (which aligns with API results)
### Changed
- `cost_per_kw[h]` input fields are now `installed_cost_per_kw[h]` to distinguish it from other costs like `om_cost_per_kw[h]`
- Financial input field refactored: `two_party_ownership` -> `third_party_ownership`
- `total_itc_pct` -> `federal_itc_pct` on technology inputs

## v0.7.3
### Fixed
- outage results processing would fail sometimes when an integer variable was not exact (e.g. 1.000000001)
- fixed `simulate_outages` for revised results formats (key names changed to align with the REopt API)

## v0.7.2
### Added
- add PV.production_factor_series input (can skip PVWatts call)
- add `run_mpc` capability, which dispatches DER for minimum energy cost over an arbitrary time horizon

## v0.7.1
### Fixed
- ElectricLoad.city default is empty string, must be filled in before annual_kwh look up

## v0.7.0
### Removed
- removed Storage.can_grid_export
### Added
- add optional integer constraint to prevent simultaneous export and import of power
- add warnings when adding integer variables
- add ability to add LinDistFlow constraints to multinode models
### Changed
- no longer require `ElectricLoad.city` input (look up ASHRAE climate zone from lat/lon)
- compatible with Julia 1.6

## v0.6.0
### Added
- add multi-node (site) capability for PV and Storage
- started documentation process using Github Pages and Documenter.jl
### Changed
- restructured outputs to align with the input structure, for example top-level keys added for `ElectricTariff` and `PV` in the outputs

## v0.5.3
### Changed
- compatible with Julia 1.5

## v0.5.2
### Fixed
- outage_simulator.jl had bug with summing over empty `Any[]`
### Added
- add optional `microgrid_only` arg to simulate_outages

## v0.5.1
### Added
- added outage dispatch outputs and speed up their derivation
### Removed
- removed redundant generator minimum turn down constraint

## v0.5.0
### Fixed
- handle missing input key for `year_one_soc_series_pct` in `outage_simulator` 
- remove erroneous `total_unserved_load = 0` output
- `dvUnservedLoad` definition was allowing microgrid production to storage and curtailment to be double counted towards meeting critical load
#### Added
- add `unserved_load_per_outage` output

## v0.4.1
### Fixed
- removed `total_unserved_load` output because it can take hours to generate and can error out when outage indices are not consecutive
### Added
- add @info for time spent processing results

## v0.4.0
### Added
- add `simulate_outages` function (similar to REopt API outage simulator)
- removed MutableArithmetics package from Project.toml (since JuMP now has method for `value(::MutableArithmetics.Zero)`)
- add outage related outputs:
    - Generator_mg_kw
    - mg_Generator_upgrade_cost
    - mg_Generator_fuel_used
    - mg_PV_upgrade_cost
    - mg_storage_upgrade_cost
    - dvUnservedLoad array
    - max_outage_cost_per_outage_duration
### Changed
- allow value_of_lost_load_per_kwh values to be subtype of Real (rather than only Real)
- add `run_reopt` method for scenario Dict

## v0.3.0
### Added
- add separate decision variables and constraints for microgrid tech capacities
    - new Site input `mg_tech_sizes_equal_grid_sizes` (boolean), when `false` the microgrid tech capacities are constrained to be <= the grid connected tech capacities
### Fixed
- allow non-integer `outage_probabilities`
- correct `total_unserved_load` output
- don't `add_min_hours_crit_ld_met_constraint` unless `min_resil_time_steps <= length(elecutil.outage_time_steps)`

## v0.2.0
### Added
- add support for custom ElectricLoad `loads_kw` input
- include existing capacity in microgrid upgrade cost
    - previously only had to pay to upgrade new capacity
- implement ElectricLoad `loads_kw_is_net` and `critical_loads_kw_is_net`
    - add existing PV production to raw load profile if `true`
- add `min_resil_time_steps` input and optional constraint for minimum time_steps that critical load must be met in every outage
### Fixed
- enforce storage cannot grid charge

## v0.1.1 Fix build.jl
deps/build.jl had a relative path dependency, fixed with an absolute path.

## v0.1.0 Initial release
This package is currently under development and only has a subset of capabilities of the REopt model used in the REopt API. For example, the Wind model, tiered electric utility tariffs, and piecewise linear cost curves are not yet modeled in this code. However this code is easier to use than the API (only dependencies are Julia and a solver) and has a novel model for uncertain outages.
