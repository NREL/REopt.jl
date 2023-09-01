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
`Boiler` results keys:
- `size_mmbtu_per_hour`  # Thermal production capacity size of the Boiler [MMBtu/hr]
- `fuel_consumption_series_mmbtu_per_hour`  # Fuel consumption series [MMBtu/hr]
- `annual_fuel_consumption_mmbtu`  # Fuel consumed in a year [MMBtu]
- `thermal_production_series_mmbtu_per_hour`  # Thermal energy production series [MMBtu/hr]
- `annual_thermal_production_mmbtu`  # Thermal energy produced in a year [MMBtu]
- `thermal_to_storage_series_mmbtu_per_hour`  # Thermal power production to TES (HotThermalStorage) series [MMBtu/hr]
- `thermal_to_steamturbine_series_mmbtu_per_hour`  # Thermal power production to SteamTurbine series [MMBtu/hr]
- `thermal_to_load_series_mmbtu_per_hour`  # Thermal power production to serve the heating load series [MMBtu/hr]
- `lifecycle_fuel_cost_after_tax`  # Life cycle fuel cost [\$]
- `year_one_fuel_cost_before_tax`  # Year one fuel cost [\$]
- `lifecycle_per_unit_prod_om_costs`  # Life cycle production-based O&M cost [\$]

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""

function add_boiler_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["size_mmbtu_per_hour"] = round(value(m[Symbol("dvSize"*_n)]["Boiler"]) / KWH_PER_MMBTU, digits=3)
	r["fuel_consumption_series_mmbtu_per_hour"] = 
        round.(value.(m[:dvFuelUsage]["Boiler", ts] for ts in p.time_steps) / KWH_PER_MMBTU, digits=3)
    r["annual_fuel_consumption_mmbtu"] = round(sum(r["fuel_consumption_series_mmbtu_per_hour"]), digits=3)

	r["thermal_production_series_mmbtu_per_hour"] = 
        round.(value.(m[:dvHeatingProduction]["Boiler", ts] for ts in p.time_steps) / KWH_PER_MMBTU, digits=5)
	r["annual_thermal_production_mmbtu"] = round(sum(r["thermal_production_series_mmbtu_per_hour"]), digits=3)

	if !isempty(p.s.storage.types.hot)
        @expression(m, BoilerToHotTESKW[ts in p.time_steps],
		    sum(m[:dvProductionToStorage][b,"Boiler",ts] for b in p.s.storage.types.hot)
            )
    else
        BoilerToHotTESKW = zeros(length(p.time_steps))
    end
	r["thermal_to_storage_series_mmbtu_per_hour"] = round.(value.(BoilerToHotTESKW / KWH_PER_MMBTU), digits=3)

    if !isempty(p.techs.steam_turbine) && p.s.boiler.can_supply_steam_turbine
        @expression(m, BoilerToSteamTurbine[ts in p.time_steps], m[:dvThermalToSteamTurbine]["Boiler",ts])
    else
        BoilerToSteamTurbine = zeros(length(p.time_steps))
    end
    r["thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(BoilerToSteamTurbine), digits=3)

	BoilerToLoad = @expression(m, [ts in p.time_steps],
		m[:dvHeatingProduction]["Boiler", ts] - BoilerToHotTESKW[ts] - BoilerToSteamTurbine[ts]
    )
	r["thermal_to_load_series_mmbtu_per_hour"] = round.(value.(BoilerToLoad / KWH_PER_MMBTU), digits=3)

    lifecycle_fuel_cost = p.pwf_fuel["Boiler"] * value(
        sum(m[:dvFuelUsage]["Boiler", ts] * p.fuel_cost_per_kwh["Boiler"][ts] for ts in p.time_steps)
    )
	r["lifecycle_fuel_cost_after_tax"] = round(lifecycle_fuel_cost * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=3)
	r["year_one_fuel_cost_before_tax"] = round(lifecycle_fuel_cost / p.pwf_fuel["Boiler"], digits=3)

    r["lifecycle_per_unit_prod_om_costs"] = round(value(m[:TotalBoilerPerUnitProdOMCosts]), digits=3)

    d["Boiler"] = r
	nothing
end