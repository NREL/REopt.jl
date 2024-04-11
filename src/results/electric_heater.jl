# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`ElectricHeater` results keys:
- `size_mmbtu_per_hour`  # Thermal production capacity size of the ElectricHeater [MMBtu/hr]
- `electric_consumption_series_kw`  # Fuel consumption series [kW]
- `annual_electric_consumption_kwh`  # Fuel consumed in a year [kWh]
- `thermal_production_series_mmbtu_per_hour`  # Thermal energy production series [MMBtu/hr]
- `annual_thermal_production_mmbtu`  # Thermal energy produced in a year [MMBtu]
- `thermal_to_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`  # Thermal power production to SteamTurbine series [MMBtu/hr]
- `thermal_to_load_series_mmbtu_per_hour`  # Thermal power production to serve the heating load series [MMBtu/hr]

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

function add_electric_heater_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_mmbtu_per_hour"] = round(value(m[Symbol("dvSize"*_n)]["ElectricHeater"]) / KWH_PER_MMBTU, digits=3)
    @expression(m, ElectricHeaterElectricConsumptionSeries[ts in p.time_steps],
        p.hours_per_time_step * sum(m[:dvThermalProduction][t,ts] / p.heating_cop[t] 
        for t in p.techs.electric_heater))
    r["electric_consumption_series_kw"] = round.(value.(ElectricHeaterElectricConsumptionSeries), digits=3)
    r["annual_electric_consumption_kwh"] = sum(r["electric_consumption_series_kw"])

	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(m[:dvThermalProduction]["ElectricHeater", ts] for ts in p.time_steps) / KWH_PER_MMBTU, digits=5)
	r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, ElectricHeaterToHotTESKW[ts in p.time_steps],
		    sum(m[:dvProductionToStorage][b,"ElectricHeater",ts] for b in p.s.storage.types.hot)
            )
    else
        ElectricHeaterToHotTESKW = zeros(length(p.time_steps))
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToHotTESKW) / KWH_PER_MMBTU, digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.electric_heater.can_supply_steam_turbine
        @expression(m, ElectricHeaterToSteamTurbine[ts in p.time_steps], m[:dvThermalToSteamTurbine]["ElectricHeater",ts])
    else
        ElectricHeaterToSteamTurbine = zeros(length(p.time_steps))
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToSteamTurbine), digits=3)

	ElectricHeaterToLoad = @expression(m, [ts in p.time_steps],
		m[:dvThermalProduction]["ElectricHeater", ts] - ElectricHeaterToHotTESKW[ts] - ElectricHeaterToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToLoad) / KWH_PER_MMBTU, digits=3)

    d["ElectricHeater"] = r
	nothing
end