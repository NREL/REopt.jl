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
    add_chp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the `CHP` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

CHP results:
- `size_kw` Power capacity size of the CHP system [kW]
- `size_supplemental_firing_kw` Power capacity of CHP supplementary firing system [kW]
- `year_one_fuel_used_mmbtu` Fuel consumed in year one [MMBtu]
- `year_one_electric_energy_produced_kwh` Electric energy produced in year one [kWh]
- `year_one_thermal_energy_produced_mmbtu` Thermal energy produced in year one [MMBtu]
- `year_one_electric_production_series_kw` Electric power production time-series array [kW]
- `year_one_to_grid_series_kw` Electric power exported time-series array [kW]
- `year_one_to_battery_series_kw` Electric power to charge the battery storage time-series array [kW]
- `year_one_to_load_series_kw` Electric power to serve the electric load time-series array [kW]
- `year_one_thermal_to_tes_series_mmbtu_per_hour` Thermal power to TES time-series array [MMBtu/hr]
- `year_one_thermal_to_waste_series_mmbtu_per_hour` Thermal power wasted/unused/vented time-series array [MMBtu/hr]
- `year_one_thermal_to_load_series_mmbtu_per_hour` Thermal power to serve the heating load time-series array [MMBtu/hr]
- `year_one_chp_fuel_cost_before_tax` Fuel cost from fuel consumed by the CHP system [\$]
- `lifecycle_chp_fuel_cost_after_tax` Fuel cost from fuel consumed by the CHP system, after tax [\$]
- `year_one_chp_standby_cost_before_tax` CHP standby charges in year one [\$] 
"""
function add_chp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
	r["size_kw"] = value(sum(m[Symbol("dvSize"*_n)][t] for t in p.techs.chp))
    r["size_supplemental_firing_kw"] = value(sum(m[Symbol("dvSupplementaryFiringSize"*_n)][t] for t in p.techs.chp))
	@expression(m, CHPFuelUsedKWH, sum(m[Symbol("dvFuelUsage"*_n)][t, ts] for t in p.techs.chp, ts in p.time_steps))
	r["year_one_fuel_used_mmbtu"] = round(value(CHPFuelUsedKWH) / KWH_PER_MMBTU, digits=3)
	@expression(m, Year1CHPElecProd,
		p.hours_per_time_step * sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts]
			for t in p.techs.chp, ts in p.time_steps))
	r["year_one_electric_energy_produced_kwh"] = round(value(Year1CHPElecProd), digits=3)
	@expression(m, Year1CHPThermalProdKWH,
		p.hours_per_time_step * sum(m[Symbol("dvThermalProduction"*_n)][t,ts] + 
        m[Symbol("dvSupplementaryThermalProduction"*_n)][t,ts] - 
        m[Symbol("dvProductionToWaste"*_n)][t,ts] 
            for t in p.techs.chp, ts in p.time_steps))
	r["year_one_thermal_energy_produced_mmbtu"] = round(value(Year1CHPThermalProdKWH) / KWH_PER_MMBTU, digits=3)
	@expression(m, CHPElecProdTotal[ts in p.time_steps],
		sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for t in p.techs.chp))
	r["year_one_electric_production_series_kw"] = round.(value.(CHPElecProdTotal), digits=3)
	@expression(m, CHPtoGrid[ts in p.time_steps], sum(m[Symbol("dvProductionToGrid"*_n)][t,u,ts]
			for t in p.techs.chp, u in p.export_bins_by_tech[t]))
	r["year_one_to_grid_series_kw"] = round.(value.(CHPtoGrid), digits=3)
	if !isempty(p.s.storage.types.elec)
		@expression(m, CHPtoBatt[ts in p.time_steps],
			sum(m[Symbol("dvProductionToStorage"*_n)]["ElectricStorage",t,ts] for t in p.techs.chp))
	else
		CHPtoBatt = zeros(length(p.time_steps))
	end
	r["year_one_to_battery_series_kw"] = round.(value.(CHPtoBatt), digits=3)
	
	@expression(m, CHPtoLoad[ts in p.time_steps],
		sum(m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.techs.chp) - CHPtoBatt[ts] - CHPtoGrid[ts])
	r["year_one_to_load_series_kw"] = round.(value.(CHPtoLoad), digits=3)
	if !isempty(p.s.storage.types.hot)
		@expression(m, CHPtoHotTES[ts in p.time_steps],
			sum(m[Symbol("dvProductionToStorage"*_n)]["HotThermalStorage",t,ts] for t in p.techs.chp))
	else 
		CHPtoHotTES = zeros(length(p.time_steps))
	end
	r["year_one_thermal_to_tes_series_mmbtu_per_hour"] = round.(value.(CHPtoHotTES / KWH_PER_MMBTU), digits=5)
    # if !isempty(p.SteamTurbineTechs)
    #     @expression(m, CHPToSteamTurbine[ts in p.time_steps], sum(m[Symbol("dvThermalToSteamTurbine"*_n)][t,ts] for t in p.techs.chp))
    #     r["year_one_thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(value.(CHPToSteamTurbine), digits=3)
    # else
    #     CHPToSteamTurbine = zeros(p.time_stepCount)
    #     r["year_one_thermal_to_steamturbine_series_mmbtu_per_hour"] = round.(CHPToSteamTurbine, digits=3)
    # end
	@expression(m, CHPThermalToWasteKW[ts in p.time_steps],
		sum(m[Symbol("dvProductionToWaste"*_n)][t,ts] for t in p.techs.chp))
	r["year_one_thermal_to_waste_series_mmbtu_per_hour"] = round.(value.(CHPThermalToWasteKW) / KWH_PER_MMBTU, digits=5)
	# @expression(m, CHPThermalToLoad[ts in p.time_steps],
	# 	sum(m[Symbol("dvThermalProduction"*_n)][t,ts] + m[Symbol("dvSupplementaryThermalProduction"*_n)][t,ts]
	# 		for t in p.techs.chp) - CHPtoHotTES[ts] - CHPToSteamTurbine[ts] - CHPThermalToWaste[ts])
    @expression(m, CHPThermalToLoadKW[ts in p.time_steps],
        sum(m[Symbol("dvThermalProduction"*_n)][t,ts] for t in p.techs.chp) - 
        CHPtoHotTES[ts] - CHPThermalToWasteKW[ts])
	r["year_one_thermal_to_load_series_mmbtu_per_hour"] = round.(value.(CHPThermalToLoadKW) / KWH_PER_MMBTU, digits=5)
    r["year_one_chp_fuel_cost_before_tax"] = round(value(m[:TotalCHPFuelCosts] / p.pwf_fuel["CHP"]), digits=3)                
	r["lifecycle_chp_fuel_cost_after_tax"] = round(value(m[:TotalCHPFuelCosts]) * p.s.financial.offtaker_tax_pct, digits=3)
	#Standby charges and hourly O&M
	r["year_one_chp_standby_cost_before_tax"] = round(value(m[Symbol("TotalCHPStandbyCharges")]) / p.pwf_e, digits=0)
	

    d["CHP"] = r
    nothing
end
