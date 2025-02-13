# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingBoiler` results keys:
- `size_mmbtu_per_hour`
- `fuel_consumption_series_mmbtu_per_hour` 
- `annual_fuel_consumption_mmbtu`
- `thermal_production_series_mmbtu_per_hour`
- `annual_thermal_production_mmbtu`
- `thermal_to_storage_series_mmbtu_per_hour` # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`
- `thermal_to_load_series_mmbtu_per_hour`
- `lifecycle_fuel_cost_after_tax`
- `year_one_fuel_cost_before_tax`

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""
function add_existing_boiler_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_mmbtu_per_hour"] = round(value(m[Symbol("dvSize"*_n)]["ExistingBoiler"]) / KWH_PER_MMBTU, digits=3)
	r["fuel_consumption_series_mmbtu_per_hour"] = 
        round.(value.(m[:dvFuelUsage]["ExistingBoiler", ts] for ts in p.time_steps) ./ KWH_PER_MMBTU, digits=5)
    r["annual_fuel_consumption_mmbtu"] = round(sum(r["fuel_consumption_series_mmbtu_per_hour"]), digits=5)

	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(sum(value.(m[:dvHeatingProduction]["ExistingBoiler", q, ts] for ts in p.time_steps) for q in p.heating_loads) ./ KWH_PER_MMBTU, digits=5)
    r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=5)

	if !isempty(p.s.storage.types.hot)
        @expression(m, BoilerToHotTESKW[ts in p.time_steps],
		    sum(m[:dvHeatToStorage][b,"ExistingBoiler",q,ts] for b in p.s.storage.types.hot, q in p.heating_loads)
            )
        @expression(m, BoilerToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps],
            sum(m[:dvHeatToStorage][b,"ExistingBoiler",q,ts] for b in p.s.storage.types.hot)
            )
    else
        BoilerToHotTESKW = zeros(length(p.time_steps))
        @expression(m, BoilerToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(BoilerToHotTESKW / KWH_PER_MMBTU), digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.existing_boiler.can_supply_steam_turbine
        @expression(m, BoilerToSteamTurbineKW[ts in p.time_steps], sum(m[:dvThermalToSteamTurbine]["ExistingBoiler",q,ts] for q in p.heating_loads))
        @expression(m, BoilerToSteamTurbineByQualityKW[q in p.heating_loads, ts in p.time_steps], m[:dvThermalToSteamTurbine]["ExistingBoiler",q,ts])
    else
        @expression(m, BoilerToSteamTurbineKW[ts in p.time_steps], 0.0)
        @expression(m, BoilerToSteamTurbineByQualityKW[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(BoilerToSteamTurbineKW) ./ KWH_PER_MMBTU, digits=5)


	BoilerToLoadKW = @expression(m, [ts in p.time_steps],
		sum(value.(m[:dvHeatingProduction]["ExistingBoiler",q,ts] for q in p.heating_loads)) - BoilerToHotTESKW[ts] - BoilerToSteamTurbineKW[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(BoilerToLoadKW ./ KWH_PER_MMBTU), digits=5)
    
    if "DomesticHotWater" in p.heating_loads && p.s.existing_boiler.can_serve_dhw
        @expression(m, BoilerToDHWKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ExistingBoiler","DomesticHotWater",ts] - BoilerToHotTESByQualityKW["DomesticHotWater",ts] - BoilerToSteamTurbineByQualityKW["DomesticHotWater",ts]
        )
    else
        @expression(m, BoilerToDHWKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_dhw_load_series_mmbtu_per_hour"] = round.(value.(BoilerToDHWKW ./ KWH_PER_MMBTU), digits=5)
    
    if "SpaceHeating" in p.heating_loads && p.s.existing_boiler.can_serve_space_heating
        @expression(m, BoilerToSpaceHeatingKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ExistingBoiler","SpaceHeating",ts] - BoilerToHotTESByQualityKW["SpaceHeating",ts] - BoilerToSteamTurbineByQualityKW["SpaceHeating",ts]
        )
    else
        @expression(m, BoilerToSpaceHeatingKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_space_heating_load_series_mmbtu_per_hour"] = round.(value.(BoilerToSpaceHeatingKW ./ KWH_PER_MMBTU), digits=5)
    
    if "ProcessHeat" in p.heating_loads && p.s.existing_boiler.can_serve_process_heat
        @expression(m, BoilerToProcessHeatKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ExistingBoiler","ProcessHeat",ts] - BoilerToHotTESByQualityKW["ProcessHeat",ts] - BoilerToSteamTurbineByQualityKW["ProcessHeat",ts]
        )
    else
        @expression(m, BoilerToProcessHeatKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_process_heat_load_series_mmbtu_per_hour"] = round.(value.(BoilerToProcessHeatKW ./ KWH_PER_MMBTU), digits=5)

    m[:TotalExistingBoilerFuelCosts] = @expression(m, p.pwf_fuel["ExistingBoiler"] *
        sum(m[:dvFuelUsage]["ExistingBoiler", ts] * p.fuel_cost_per_kwh["ExistingBoiler"][ts] for ts in p.time_steps)
    )
	r["lifecycle_fuel_cost_after_tax"] = round(value(m[:TotalExistingBoilerFuelCosts]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=3)
	r["year_one_fuel_cost_before_tax"] = round(value(m[:TotalExistingBoilerFuelCosts]) / p.pwf_fuel["ExistingBoiler"], digits=3)

    d["ExistingBoiler"] = r
	nothing
end