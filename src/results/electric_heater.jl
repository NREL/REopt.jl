# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
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
        p.hours_per_time_step * sum(m[:dvHeatingProduction][t,q,ts] / p.heating_cop[t] 
        for q in p.heating_loads, t in p.techs.electric_heater))
    r["electric_consumption_series_kw"] = round.(value.(ElectricHeaterElectricConsumptionSeries), digits=3)
    r["annual_electric_consumption_kwh"] = sum(r["electric_consumption_series_kw"])

    @expression(m, ElectricHeaterThermalProductionSeries[ts in p.time_steps],
        sum(m[:dvHeatingProduction][t,q,ts] for q in p.heating_loads, t in p.techs.electric_heater))
	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(ElectricHeaterThermalProductionSeries) / KWH_PER_MMBTU, digits=5)
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
		sum(m[:dvHeatingProduction]["ElectricHeater", q, ts] for q in p.heating_loads) - ElectricHeaterToHotTESKW[ts] - ElectricHeaterToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToLoad / KWH_PER_MMBTU), digits=3)

    if "DomesticHotWater" in p.heating_loads && p.s.electric_heater.can_serve_dhw
        @expression(m, ElectricHeaterToDHWKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ElectricHeater","DomesticHotWater",ts] #- ElectricHeaterToHotTESKW[ts] - ElectricHeaterToSteamTurbineKW[ts]
        )
    else
        @expression(m, ElectricHeaterToDHWKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_dhw_load_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToDHWKW ./ KWH_PER_MMBTU), digits=5)
    
    if "SpaceHeating" in p.heating_loads && p.s.electric_heater.can_serve_space_heating
        @expression(m, ElectricHeaterToSpaceHeatingKW[ts in p.time_steps], 
            m[:dvHeatingProduction]["ElectricHeater","SpaceHeating",ts] #- ElectricHeaterToHotTESKW[ts] - ElectricHeaterToSteamTurbineKW[ts]
        )
    else
        @expression(m, ElectricHeaterToSpaceHeatingKW[ts in p.time_steps], 0.0)
    end
    r["thermal_to_space_heating_load_series_mmbtu_per_hour"] = round.(value.(ElectricHeaterToSpaceHeatingKW ./ KWH_PER_MMBTU), digits=5)

    d["ElectricHeater"] = r
	nothing
end