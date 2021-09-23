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
function add_existing_boiler_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    # TODO all of these time series assume hourly time steps
    # TODO we convert MMBTU_TO_KWH from user inputs to the model, and then back to mmbtu in outputs: why not stay in mmbtu?
	r["year_one_boiler_fuel_consumption_mmbtu_per_hr"] = 
        round.(value.(m[:dvFuelUsage]["ExistingBoiler", ts] for ts in p.time_steps) / MMBTU_TO_KWH, digits=3)
    r["year_one_boiler_fuel_consumption_mmbtu"] = round(sum(r["year_one_boiler_fuel_consumption_mmbtu_per_hr"]), digits=3)

	r["year_one_boiler_thermal_production_mmbtu_per_hr"] = 
        round.(value.(m[:dvThermalProduction]["ExistingBoiler", ts] for ts in p.time_steps) / MMBTU_TO_KWH, digits=3)
	r["year_one_boiler_thermal_production_mmbtu"] = round(sum(r["year_one_boiler_thermal_production_mmbtu_per_hr"]), digits=3)

	# @expression(m, BoilerToHotTES[ts in p.time_steps],
	# 	m[:dvProductionToStorage]["HotTES","ExistingBoiler",ts])

	# r["boiler_thermal_to_tes_series"] = round.(value.(BoilerToHotTES), digits=3)

    # if !isempty(p.SteamTurbineTechs)
    #     @expression(m, BoilerToSteamTurbine[ts in p.time_steps], m[:dvThermalToSteamTurbine]["ExistingBoiler",ts])
    #     r["boiler_thermal_to_steamturbine_series"] = round.(value.(BoilerToSteamTurbine), digits=3)
    # else
    #     BoilerToSteamTurbine = zeros(p.time_stepsCount)
    #     r["boiler_thermal_to_steamturbine_series"] = round.(BoilerToSteamTurbine, digits=3)
    # end

	# @expression(m, BoilerToLoad[ts in p.time_steps],
	# 	m[:dvThermalProduction]["ExistingBoiler",ts] - BoilerToHotTES[ts] - BoilerToSteamTurbine[ts])
	# r["boiler_thermal_to_load_series"] = round.(value.(BoilerToLoad), digits=3)

	@expression(m, TotalBoilerFuelCharges,
		p.pwf_fuel["ExistingBoiler"] * p.hours_per_timestep * sum(
            p.s.existing_boiler.fuel_cost_series[ts] * m[:dvFuelUsage]["ExistingBoiler", ts] for ts in p.time_steps
        )
    )
	r["total_boiler_fuel_cost"] = round(value(TotalBoilerFuelCharges) * (1 - p.s.financial.offtaker_tax_pct), digits=3)
	r["year_one_boiler_fuel_cost"] = round(value(TotalBoilerFuelCharges) / p.pwf_fuel["ExistingBoiler"], digits=3)

    d["ExistingBoiler"] = r
	nothing
end