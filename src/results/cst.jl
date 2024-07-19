# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`ConcentratingSolar` results keys:
- `size_kw`  # Thermal production capacity size of the ConcentratingSolar [MMBtu/hr]
- `electric_consumption_series_kw`  # Fuel consumption series [kW]
- `annual_electric_consumption_kwh`  # Fuel consumed in a year [kWh]
- `thermal_production_series_mmbtu_per_hour`  # Thermal energy production series [MMBtu/hr]
- `annual_thermal_production_mmbtu`  # Thermal energy produced in a year [MMBtu]
- `thermal_to_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_hot_sensible_tes_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`  # Thermal power production to SteamTurbine series [MMBtu/hr]
- `thermal_to_load_series_mmbtu_per_hour`  # Thermal power production to serve the heating load series [MMBtu/hr]

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

function add_concentrating_solar_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["ConcentratingSolar"]) / KWH_PER_MMBTU, digits=3)
    @expression(m, ConcentratingSolarElectricConsumptionSeries[ts in p.time_steps],
        p.hours_per_time_step * sum(m[:dvHeatingProduction]["ConcentratingSolar",q,ts] / p.heating_cop["ConcentratingSolar"] 
        for q in p.heating_loads))
    r["electric_consumption_series_kw"] = round.(value.(ConcentratingSolarElectricConsumptionSeries), digits=3)
    r["annual_electric_consumption_kwh"] = sum(r["electric_consumption_series_kw"])

    @expression(m, ConcentratingSolarThermalProductionSeries[ts in p.time_steps],
        sum(m[:dvHeatingProduction]["ConcentratingSolar",q,ts] for q in p.heating_loads))
	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(ConcentratingSolarThermalProductionSeries) / KWH_PER_MMBTU, digits=5)
	r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, ConcentratingSolarToHotTESKW[ts in p.time_steps],
		    sum(m[:dvHeatToStorage][b,"ConcentratingSolar",q,ts] for b in p.s.storage.types.hot, q in p.heating_loads)
            )
        @expression(m, ConcentratingSolarToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 
            sum(m[:dvHeatToStorage][b,"ConcentratingSolar",q,ts] for b in p.s.storage.types.hot)
            )
        if "HotSensibleTes" in p.s.storage.types.hot
            @expression(m, ConcentratingSolarToHotSensibleTESKW[ts in p.time_steps],
                sum(m[:dvHeatToStorage]["HotSensibleTes","ConcentratingSolar",q,ts] for q in p.heating_loads)
                )
        else
            @expression(m, ConcentratingSolarToHotSensibleTESKW[ts in p.time_steps], 0.0)
        end
    else
        @expression(m, ConcentratingSolarToHotTESKW[ts in p.time_steps], 0.0)
        @expression(m, ConcentratingSolarToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 0.0)
        @expression(m, ConcentratingSolarToHotSensibleTESKW[ts in p.time_steps], 0.0)
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToHotTESKW) / KWH_PER_MMBTU, digits=3)
    r["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToHotSensibleTESKW) / KWH_PER_MMBTU, digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.cst.can_supply_steam_turbine
        @expression(m, ConcentratingSolarToSteamTurbine[ts in p.time_steps], sum(m[:dvThermalToSteamTurbine]["ConcentratingSolar",q,ts] for q in p.heating_loads))
        @expression(m, ConcentratingSolarToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], m[:dvThermalToSteamTurbine]["ConcentratingSolar",q,ts])
    else
        ConcentratingSolarToSteamTurbine = zeros(length(p.time_steps))
        @expression(m, ConcentratingSolarToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToSteamTurbine) / KWH_PER_MMBTU, digits=3)

	@expression(m, ConcentratingSolarToLoad[ts in p.time_steps],
		sum(m[:dvHeatingProduction]["ConcentratingSolar", q, ts] for q in p.heating_loads) - ConcentratingSolarToHotTESKW[ts] - ConcentratingSolarToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToLoad) / KWH_PER_MMBTU, digits=3)

    if "DomesticHotWater" in p.heating_loads && p.s.cst.can_serve_dhw
        @expression(m, ConcentratingSolarToDHWKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ConcentratingSolar","DomesticHotWater",ts] - ConcentratingSolarToHotTESByQualityKW["DomesticHotWater",ts] - ConcentratingSolarToSteamTurbineByQuality["DomesticHotWater",ts]
        )
    else
        @expression(m, ConcentratingSolarToDHWKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_dhw_load_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToDHWKW ./ KWH_PER_MMBTU), digits=5)
    
    if "SpaceHeating" in p.heating_loads && p.s.cst.can_serve_space_heating
        @expression(m, ConcentratingSolarToSpaceHeatingKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ConcentratingSolar","SpaceHeating",ts] - ConcentratingSolarToHotTESByQualityKW["SpaceHeating",ts] - ConcentratingSolarToSteamTurbineByQuality["SpaceHeating",ts]
        )
    else
        @expression(m, ConcentratingSolarToSpaceHeatingKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_space_heating_load_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToSpaceHeatingKW ./ KWH_PER_MMBTU), digits=5)
    
    if "ProcessHeat" in p.heating_loads && p.s.cst.can_serve_process_heat
        @expression(m, ConcentratingSolarToProcessHeatKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ConcentratingSolar","ProcessHeat",ts] - ConcentratingSolarToHotTESByQualityKW["ProcessHeat",ts] - ConcentratingSolarToSteamTurbineByQuality["ProcessHeat",ts]
        )
    else
        @expression(m, ConcentratingSolarToProcessHeatKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_process_heat_load_series_mmbtu_per_hour"] = round.(value.(ConcentratingSolarToProcessHeatKW ./ KWH_PER_MMBTU), digits=5)

    d["ConcentratingSolar"] = r
	nothing
end