# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`ASHP` results keys:
- `size_mmbtu_per_hour`  # Thermal production capacity size of the ASHP [MMBtu/hr]
- `electric_consumption_series_kw`  # Fuel consumption series [kW]
- `annual_electric_consumption_kwh`  # Fuel consumed in a year [kWh]
- `thermal_production_series_mmbtu_per_hour`  # Thermal energy production series [MMBtu/hr]
- `annual_thermal_production_mmbtu`  # Thermal energy produced in a year [MMBtu]
- `thermal_to_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`  # Thermal power production to SteamTurbine series [MMBtu/hr]
- `thermal_to_load_series_mmbtu_per_hour`  # Thermal power production to serve the heating load series [MMBtu/hr]
- `thermal_to_storage_series_ton` # Thermal production to ColdThermalStorage
- `thermal_to_load_series_ton` # Thermal production to cooling load
- `electric_consumption_series_kw`
- `annual_electric_consumption_kwh`
- `annual_thermal_production_tonhour`


!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

function add_ashp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_mmbtu_per_hour"] = round(value(m[Symbol("dvSize"*_n)]["ASHP"]) / KWH_PER_MMBTU, digits=3)
    @expression(m, ASHPElectricConsumptionSeries[ts in p.time_steps],
        p.hours_per_time_step * sum(m[:dvHeatingProduction][t,q,ts] / p.heating_cop[t][ts] #p.heating_cop[t,ts] 
        for q in p.heating_loads, t in p.techs.ashp) 
    ) 

    @expression(m, ASHPThermalProductionSeries[ts in p.time_steps],
        sum(m[:dvHeatingProduction][t,q,ts] for q in p.heating_loads, t in p.techs.ashp)) # TODO add cooling
	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(ASHPThermalProductionSeries) / KWH_PER_MMBTU, digits=5)
	r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, ASHPToHotTESKW[ts in p.time_steps],
		    sum(m[:dvHeatToStorage][b,"ASHP",q,ts] for b in p.s.storage.types.hot, q in p.heating_loads)
        )
        @expression(m, ASHPToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 
            sum(m[:dvHeatToStorage][b,"ASHP",q,ts] for b in p.s.storage.types.hot)
        )
    else
        @expression(m, ASHPToHotTESKW[ts in p.time_steps], 0.0)
        @expression(m, ASHPToHotTESByQualityKW[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(ASHPToHotTESKW) / KWH_PER_MMBTU, digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.ashp.can_supply_steam_turbine
        @expression(m, ASHPToSteamTurbine[ts in p.time_steps], sum(m[:dvThermalToSteamTurbine]["ASHP",q,ts] for q in p.heating_loads))
        @expression(m, ASHPToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], m[:dvThermalToSteamTurbine]["ASHP",q,ts])
    else
        ASHPToSteamTurbine = zeros(length(p.time_steps))
        @expression(m, ASHPToSteamTurbineByQuality[q in p.heating_loads, ts in p.time_steps], 0.0)
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(ASHPToSteamTurbine) / KWH_PER_MMBTU, digits=3)

	@expression(m, ASHPToLoad[ts in p.time_steps],
		sum(m[:dvHeatingProduction]["ASHP", q, ts] for q in p.heating_loads) - ASHPToHotTESKW[ts] - ASHPToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(ASHPToLoad) ./ KWH_PER_MMBTU, digits=3)

    if "DomesticHotWater" in p.heating_loads && p.s.ashp.can_serve_dhw
        @expression(m, ASHPToDHWKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP","DomesticHotWater",ts] - ASHPToHotTESByQualityKW["DomesticHotWater",ts] - ASHPToSteamTurbineByQuality["DomesticHotWater",ts]
        )
    else
        @expression(m, ASHPToDHWKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_dhw_load_series_mmbtu_per_hour"] = round.(value.(ASHPToDHWKW ./ KWH_PER_MMBTU), digits=5)
    
    if "SpaceHeating" in p.heating_loads && p.s.ashp.can_serve_space_heating
        @expression(m, ASHPToSpaceHeatingKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP","SpaceHeating",ts] - ASHPToHotTESByQualityKW["SpaceHeating",ts] - ASHPToSteamTurbineByQuality["SpaceHeating",ts]
        )
    else
        @expression(m, ASHPToSpaceHeatingKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_space_heating_load_series_mmbtu_per_hour"] = round.(value.(ASHPToSpaceHeatingKW ./ KWH_PER_MMBTU), digits=5)
    
    if "ProcessHeat" in p.heating_loads && p.s.ashp.can_serve_space_heating
        @expression(m, ASHPToProcessHeatKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ASHP","ProcessHeat",ts] - ASHPToHotTESByQualityKW["ProcessHeat",ts] - ASHPToSteamTurbineByQuality["ProcessHeat",ts]
        )
    else
        @expression(m, ASHPToProcessHeatKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_process_heat_load_series_mmbtu_per_hour"] = round.(value.(ASHPToProcessHeatKW ./ KWH_PER_MMBTU), digits=5)
    
    if "ASHP" in p.techs.cooling && sum(p.s.cooling_load.loads_kw_thermal) > 0.0

        @expression(m, ASHPtoColdTES[ts in p.time_steps],
            sum(m[:dvProductionToStorage][b,"ASHP",ts] for b in p.s.storage.types.cold)
        )
        r["thermal_to_storage_series_ton"] = round.(value.(ASHPtoColdTES ./ KWH_THERMAL_PER_TONHOUR), digits=3)   

        @expression(m, ASHPtoColdLoad[ts in p.time_steps],
            sum(m[:dvCoolingProduction]["ASHP", ts]) - ASHPtoColdTES[ts]
        )
        r["thermal_to_load_series_ton"] = round.(value.(ASHPtoColdLoad ./ KWH_THERMAL_PER_TONHOUR), digits=3)

        @expression(m, Year1ASHPColdThermalProd,
            p.hours_per_time_step * sum(m[:dvCoolingProduction]["ASHP", ts] for ts in p.time_steps)
        )
        r["annual_thermal_production_tonhour"] = round(value(Year1ASHPColdThermalProd / KWH_THERMAL_PER_TONHOUR), digits=3)
        
        @expression(m, ASHPColdElectricConsumptionSeries[ts in p.time_steps], 
            p.hours_per_time_step * sum(m[:dvCoolingProduction][t,ts] / p.cooling_cop[t][ts] 
            for t in p.techs.ashp)
        )
    else
        r["thermal_to_storage_series_ton"] = zeros(length(p.time_steps))
        r["thermal_to_load_series_ton"] = zeros(length(p.time_steps))
        r["annual_thermal_production_tonhour"] = 0.0
        @expression(m, ASHPColdElectricConsumptionSeries, 0.0)
    end
    r["electric_consumption_series_kw"] = round.(value.(ASHPElectricConsumptionSeries .+ ASHPColdElectricConsumptionSeries), digits=3)
    r["annual_electric_consumption_kwh"] = p.hours_per_time_step * sum(r["electric_consumption_series_kw"])

    d["ASHP"] = r
	nothing
end