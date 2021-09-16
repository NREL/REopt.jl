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
function add_wind_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    t = "Wind"
	per_unit_size_om = @expression(m, p.third_party_factor * p.pwf_om * m[:dvSize][t] * p.om_cost_per_kw[t])

	r["size_kw"] = round(value(m[:dvSize][t]), digits=2)
	r["total_om_cost"] = round(value(per_unit_size_om) * (1 - p.s.financial.owner_tax_pct), digits=0)
	r["year_one_om_cost"] = round(value(per_unit_size_om) / (p.pwf_om * p.third_party_factor), digits=0)

	prod_to_storage = @expression(m, [ts in p.time_steps],
		sum(m[:dvProductionToStorage][b, t, ts] for b in p.s.storage.types, t in p.gentechs))
	r["year_one_to_battery_series_kw"] = round.(value.(prod_to_storage), digits=3)

    r["year_one_to_grid_series_kw"] = zeros(size(r["year_one_to_battery_series_kw"]))
    r["average_annual_energy_exported_kwh"] = 0.0
    if !isempty(p.s.electric_tariff.export_bins)
        wind_to_grid = @expression(m, [ts in p.time_steps],
                sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
        r["year_one_to_grid_series_kw"] = round.(value.(wind_to_grid), digits=3).data

        r["average_annual_energy_exported_kwh"] = round(
            sum(r["year_one_to_grid_series_kw"]) * p.hours_per_timestep, digits=0)
    end

	generatorToGrid = @expression(m, [ts in p.time_steps],
		sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t])
	)
	r["year_one_to_grid_series_kw"] = round.(value.(generatorToGrid), digits=3)

	prod_to_load = @expression(m, [ts in p.time_steps],
		    m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t] -
			prod_to_storage[ts] - generatorToGrid[ts]
	)
	r["year_one_to_load_series_kw"] = round.(value.(prod_to_load), digits=3)

	Year1GenProd = @expression(m,
		p.hours_per_timestep * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts]
			for ts in p.time_steps)
	)
	r["year_one_energy_produced_kwh"] = round(value(Year1GenProd), digits=0)
	AverageGenProd = @expression(m,
		p.hours_per_timestep * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts] *
		p.levelization_factor[t] for ts in p.time_steps)
	)
	r["average_annual_energy_produced_kwh"] = round(value(AverageGenProd), digits=0)

    WindToCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
    r["year_one_curtailed_production_series_kw"] = round.(value.(WindToCUR), digits=3)
    r["lcoe_per_kwh"] = calculate_lcoe(p, r, p.s.wind)

	d["Wind"] = r
    nothing
end
