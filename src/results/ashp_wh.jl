# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`ASHP_WH` results keys:
- `size_ton`  # Thermal production capacity size of the ASHP_WH [ton/hr]
- `electric_consumption_series_kw`  # Fuel consumption series [kW]
- `annual_electric_consumption_kwh`  # Fuel consumed in a year [kWh]
- `thermal_production_series_mmbtu_per_hour`  # Thermal heating energy production series [MMBtu/hr]
- `annual_thermal_production_mmbtu`  # Thermal heating energy produced in a year [MMBtu]
- `thermal_to_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`  # Thermal power production to SteamTurbine series [MMBtu/hr]
- `thermal_to_load_series_mmbtu_per_hour`  # Thermal power production to serve the heating load series [MMBtu/hr]
- `thermal_to_storage_series_ton` # Thermal production to ColdThermalStorage
- `thermal_to_load_series_ton` # Thermal production to cooling load
- `electric_consumption_series_kw`
- `annual_electric_consumption_kwh`


!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

function add_ashp_wh_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_ton"] = round(value(m[Symbol("dvSize"*_n)]["ASHP_WH"]) / KWH_THERMAL_PER_TONHOUR, digits=3)
    @expression(m, ASHPWHElectricConsumptionSeries[ts in p.time_steps],
        p.hours_per_time_step * sum(m[:dvHeatingProduction][t,q,ts] / p.heating_cop[t][ts]
        for q in p.heating_loads, t in p.techs.ashp_wh) 
    ) 

    @expression(m, ASHPWHThermalProductionSeries[ts in p.time_steps],
        sum(m[:dvHeatingProduction][t,q,ts] for q in p.heating_loads, t in p.techs.ashp_wh))
	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(ASHPWHThermalProductionSeries) / KWH_PER_MMBTU, digits=5)
	r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, ASHPWHToHotTESKW[ts in p.time_steps],
		    sum(m[:dvHeatToStorage][b,"ASHP_WH",q,ts] for b in p.s.storage.types.hot, q in p.heating_loads)
        )
        @expression(m, ASHPWHToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 
            sum(m[:dvHeatToStorage][b,"ASHP_WH",q,ts] for b in p.s.storage.types.hot)
        )
    else
        @expression(m, ASHPWHToHotTESKW[ts in p.time_steps], 0.0)
        @expression(m, ASHPWHToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(ASHPWHToHotTESKW) / KWH_PER_MMBTU, digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.ashp_wh.can_supply_steam_turbine
        @expression(m, ASHPWHToSteamTurbine[ts in p.time_steps], sum(m[:dvThermalToSteamTurbine]["ASHP_WH",q,ts] for q in p.heating_loads))
        @expression(m, ASHPWHToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], m[:dvThermalToSteamTurbine]["ASHP_WH",q,ts])
    else
        ASHPWHToSteamTurbine = zeros(length(p.time_steps))
        @expression(m, ASHPWHToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(ASHPWHToSteamTurbine) / KWH_PER_MMBTU, digits=3)

	@expression(m, ASHPWHToLoad[ts in p.time_steps],
		sum(m[:dvHeatingProduction]["ASHP_WH", q, ts] for q in p.heating_loads) - ASHPWHToHotTESKW[ts] - ASHPWHToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(ASHPWHToLoad) ./ KWH_PER_MMBTU, digits=3)

    if "DomesticHotWater" in p.heating_loads && p.s.ashp_wh.can_serve_dhw
        @expression(m, ASHPWHToDHWKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP_WH","DomesticHotWater",ts] - ASHPWHToHotTESByQualityKW["DomesticHotWater",ts] - ASHPWHToSteamTurbineByQuality["DomesticHotWater",ts]
        )
    else
        @expression(m, ASHPWHToDHWKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_dhw_load_series_mmbtu_per_hour"] = round.(value.(ASHPWHToDHWKW ./ KWH_PER_MMBTU), digits=5)
    
    if "SpaceHeating" in p.heating_loads && p.s.ashp_wh.can_serve_space_heating
        @expression(m, ASHPWHToSpaceHeatingKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP_WH","SpaceHeating",ts] - ASHPWHToHotTESByQualityKW["SpaceHeating",ts] - ASHPWHToSteamTurbineByQuality["SpaceHeating",ts]
        )
    else
        @expression(m, ASHPWHToSpaceHeatingKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_space_heating_load_series_mmbtu_per_hour"] = round.(value.(ASHPWHToSpaceHeatingKW ./ KWH_PER_MMBTU), digits=5)
    
    if "ProcessHeat" in p.heating_loads && p.s.ashp_wh.can_serve_space_heating
        @expression(m, ASHPWHToProcessHeatKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP_WH","ProcessHeat",ts] - ASHPWHToHotTESByQualityKW["ProcessHeat",ts] - ASHPWHToSteamTurbineByQuality["ProcessHeat",ts]
        )
    else
        @expression(m, ASHPWHToProcessHeatKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_process_heat_load_series_mmbtu_per_hour"] = round.(value.(ASHPWHToProcessHeatKW ./ KWH_PER_MMBTU), digits=5)
    
    r["electric_consumption_series_kw"] = round.(value.(ASHPWHElectricConsumptionSeries), digits=3)
    r["annual_electric_consumption_kwh"] = p.hours_per_time_step * sum(r["electric_consumption_series_kw"])

    d["ASHP_WH"] = r
	nothing
end