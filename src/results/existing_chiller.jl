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
`ExistingChiller` results keys:
- `thermal_to_storage_series_ton` # Thermal production to ColdThermalStorage
- `thermal_to_load_series_ton` # Thermal production to cooling load
- `electric_consumption_series_kw`
- `annual_electric_consumption_kwh`
- `annual_thermal_production_tonhour`

"""
function add_existing_chiller_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()

	@expression(m, ELECCHLtoTES[ts in p.time_steps],
		sum(m[:dvProductionToStorage][b,"ExistingChiller",ts] for b in p.s.storage.types.cold)
    )
	r["thermal_to_storage_series_ton"] = round.(value.(ELECCHLtoTES / KWH_THERMAL_PER_TONHOUR), digits=3)   

	@expression(m, ELECCHLtoLoad[ts in p.time_steps],
		sum(m[:dvCoolingProduction]["ExistingChiller", ts])
			- ELECCHLtoTES[ts]
    )
	r["thermal_to_load_series_ton"] = round.(value.(ELECCHLtoLoad / KWH_THERMAL_PER_TONHOUR).data, digits=3)

	@expression(m, ELECCHLElecConsumptionSeries[ts in p.time_steps],
		sum(m[:dvCoolingProduction]["ExistingChiller", ts] / p.cop["ExistingChiller"])
    )
	r["electric_consumption_series_kw"] = round.(value.(ELECCHLElecConsumptionSeries).data, digits=3)

	@expression(m, Year1ELECCHLElecConsumption,
		p.hours_per_time_step * sum(m[:dvCoolingProduction]["ExistingChiller", ts] / p.cop["ExistingChiller"]
			for ts in p.time_steps)
    )
	r["annual_electric_consumption_kwh"] = round(value(Year1ELECCHLElecConsumption), digits=3)

	@expression(m, Year1ELECCHLThermalProd,
		p.hours_per_time_step * sum(m[:dvCoolingProduction]["ExistingChiller", ts]
			for ts in p.time_steps)
    )
	r["annual_thermal_production_tonhour"] = round(value(Year1ELECCHLThermalProd / KWH_THERMAL_PER_TONHOUR), digits=3)

    d["ExistingChiller"] = r
	nothing
end