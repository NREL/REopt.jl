# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricUtility` results keys:
- `annual_energy_supplied_kwh` Total energy supplied from the grid in an average year.
- `electric_to_load_series_kw` Vector of power drawn from the grid to serve load.
- `electric_to_storage_series_kw` Vector of power drawn from the grid to charge the battery.
- `annual_emissions_tonnes_CO2` # Total tons of CO2 emissions associated with the site's grid-purchased electricity in an average year. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `annual_emissions_tonnes_NOx` # Total tons of NOx emissions associated with the site's grid-purchased electricity in an average year. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `annual_emissions_tonnes_SO2` # Total tons of SO2 emissions associated with the site's grid-purchased electricity in an average year. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `annual_emissions_tonnes_PM25` # Total tons of PM2.5 emissions associated with the site's grid-purchased electricity in an average year. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `lifecycle_emissions_tonnes_CO2` # Total tons of CO2 emissions associated with the site's grid-purchased electricity over the analysis period. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `lifecycle_emissions_tonnes_NOx` # Total tons of NOx emissions associated with the site's grid-purchased electricity over the analysis period. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `lifecycle_emissions_tonnes_SO2` # Total tons of SO2 emissions associated with the site's grid-purchased electricity over the analysis period. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `lifecycle_emissions_tonnes_PM25` # Total tons of PM2.5 emissions associated with the site's grid-purchased electricity over the analysis period. If include_exported_elec_emissions_in_total is False, this value only reflects grid purchaes. Otherwise, it accounts for emissions offset from any export to the grid.
- `emissions_region` # EPA AVERT region of the site (populated if default emissions values are used).
- `distance_to_emissions_region_meters`

!!! note "'Series' and 'Annual' energy and emissions outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy and emissions outputs averaged over the analysis period. 

!!! note "Emissions outputs" 
    By default, REopt uses marginal emissions rates for grid-purchased electricity. Marginal emissions rates are most appropriate for reporting a change in emissions (avoided or increased) rather than emissions totals.
    It is therefore recommended that emissions results from REopt (using default marginal emissions rates) be reported as the difference in emissions between the optimized and BAU case.

"""
function add_electric_utility_results(m::JuMP.AbstractModel, p::AbstractInputs, d::Dict; _n="")
    # Adds the `ElectricUtility` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_time_step * sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] 
        for ts in p.time_steps, tier in 1:p.s.electric_tariff.n_energy_tiers)
    r["annual_energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)
    
    if !isempty(p.s.storage.types.elec)
        GridToLoad = (sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) 
                  - sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types.elec)
                  - sum(m[Symbol("dvGridToElectrolyzer"*_n)][ts])
                  - sum(m[Symbol("dvGridToCompressor"*_n)][ts])
                  for ts in p.time_steps)
        GridToBatt = (sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types.elec) 
                for ts in p.time_steps)
    else
        GridToLoad = (sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) 
                    - sum(m[Symbol("dvGridToElectrolyzer"*_n)][ts])
                    - sum(m[Symbol("dvGridToCompressor"*_n)][ts])
                    for ts in p.time_steps)
        GridToBatt = zeros(length(p.time_steps))
    end
    
    r["electric_to_load_series_kw"] = round.(value.(GridToLoad), digits=3)
    r["electric_to_storage_series_kw"] = round.(value.(GridToBatt), digits=3)

    if !isempty(p.techs.electrolyzer)
        GridToElectrolyzer = (m[Symbol("dvGridToElectrolyzer"*_n)][ts] for ts in p.time_steps)
        r["electric_to_electrolyzer_series_kw"] = round.(value.(GridToElectrolyzer), digits=6)
    end

    if !isempty(p.techs.compressor)
        GridToCompressor = (m[Symbol("dvGridToCompressor"*_n)][ts] for ts in p.time_steps)
        r["electric_to_compressor_series_kw"] = round.(value.(GridToCompressor), digits=3)
    end

    if _n=="" #only output emissions results if not a multinode model
        r["annual_emissions_tonnes_CO2"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_CO2]*TONNE_PER_LB), digits=2)
        r["annual_emissions_tonnes_NOx"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_NOx]*TONNE_PER_LB), digits=2)
        r["annual_emissions_tonnes_SO2"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_SO2]*TONNE_PER_LB), digits=2)
        r["annual_emissions_tonnes_PM25"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_PM25]*TONNE_PER_LB), digits=2)
        r["lifecycle_emissions_tonnes_CO2"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_CO2]*TONNE_PER_LB*p.pwf_grid_emissions["CO2"]), digits=2)
        r["lifecycle_emissions_tonnes_NOx"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_NOx]*TONNE_PER_LB*p.pwf_grid_emissions["NOx"]), digits=2)
        r["lifecycle_emissions_tonnes_SO2"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_SO2]*TONNE_PER_LB*p.pwf_grid_emissions["SO2"]), digits=2)
        r["lifecycle_emissions_tonnes_PM25"] = round(value(m[:yr1_emissions_from_elec_grid_net_if_selected_lbs_PM25]*TONNE_PER_LB*p.pwf_grid_emissions["PM25"]), digits=2)
        
        r["emissions_region"] = p.s.electric_utility.emissions_region
        r["distance_to_emissions_region_meters"] = p.s.electric_utility.distance_to_emissions_region_meters
    end

    d["ElectricUtility"] = r

    nothing
end

"""
MPC `ElectricUtility` results keys:
- `energy_supplied_kwh` 
- `to_battery_series_kw`
- `to_load_series_kw`
"""
function add_electric_utility_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_time_step * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for ts in p.time_steps, 
                                                         tier in 1:p.s.electric_tariff.n_energy_tiers)
    r["energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)

    if p.s.storage.attr["ElectricStorage"].size_kwh > 0
        GridToBatt = @expression(m, [ts in p.time_steps], 
            sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types.elec) 
		)
        r["to_battery_series_kw"] = round.(value.(GridToBatt), digits=3).data
    else
        GridToBatt = zeros(length(p.time_steps))
    end
    GridToLoad = @expression(m, [ts in p.time_steps], 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - 
        GridToBatt[ts]
    )
    r["to_load_series_kw"] = round.(value.(GridToLoad), digits=3).data

    d["ElectricUtility"] = r
    nothing
end