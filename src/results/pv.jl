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
function add_pv_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    for t in p.pvtechs
        r = Dict{String, Any}()
		r["size_kw"] = round(value(m[Symbol("dvSize"*_n)][t]), digits=4)

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if !isempty(p.s.storage.types)
			PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types) for ts in p.time_steps)
		else
			PVtoBatt = repeat([0], length(p.time_steps))
		end
		r["year_one_to_battery_series_kw"] = round.(value.(PVtoBatt), digits=3)

        r["year_one_to_grid_series_kw"] = zeros(size(r["year_one_to_battery_series_kw"]))
        r["average_annual_energy_exported_kwh"] = 0.0
        if !isempty(p.s.electric_tariff.export_bins)
            PVtoGrid = @expression(m, [ts in p.time_steps],
                    sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
            r["year_one_to_grid_series_kw"] = round.(value.(PVtoGrid), digits=3).data

            r["average_annual_energy_exported_kwh"] = round(
                sum(r["year_one_to_grid_series_kw"]) * p.hours_per_timestep, digits=0)
        end

		PVtoCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
		r["year_one_curtailed_production_series_kw"] = round.(value.(PVtoCUR), digits=3)
		PVtoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
					- r["year_one_curtailed_production_series_kw"][ts]
					- r["year_one_to_grid_series_kw"][ts]
					- r["year_one_to_battery_series_kw"][ts] for ts in p.time_steps
		)
		r["year_one_to_load_series_kw"] = round.(value.(PVtoLoad), digits=3)
		Year1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_timestep)
		r["year_one_energy_produced_kwh"] = round(value(Year1PvProd), digits=0)
        r["average_annual_energy_produced_kwh"] = round(r["year_one_energy_produced_kwh"] * p.levelization_factor[t], digits=2)
		PVPerUnitSizeOMCosts = p.om_cost_per_kw[t] * p.pwf_om * m[Symbol("dvSize"*_n)][t]
		r["total_om_cost"] = round(value(PVPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_pct), digits=0)
        r["lcoe_per_kwh"] = calculate_lcoe(p, r, get_pv_by_name(t, p.s.pvs))
        d[t] = r
	end
    nothing
end


function add_pv_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    for t in p.pvtechs
        r = Dict{String, Any}()

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if p.s.storage.size_kw[:elec] > 0  # TODO handle multiple storage types
			PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types) for ts in p.time_steps)
            PVtoBatt = round.(value.(PVtoBatt), digits=3)
            r["to_battery_series_kw"] = PVtoBatt
		else
			PVtoBatt = repeat([0], length(p.time_steps))
		end

        r["to_grid_series_kw"] = zeros(length(p.time_steps))
        if !isempty(p.s.electric_tariff.export_bins)
            PVtoGrid = @expression(m, [ts in p.time_steps],
                    sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
            r["to_grid_series_kw"] = round.(value.(PVtoGrid), digits=3).data
        end

		PVtoCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
		r["curtailed_production_series_kw"] = round.(value.(PVtoCUR), digits=3)
		PVtoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
					- r["curtailed_production_series_kw"][ts]
					- r["to_grid_series_kw"][ts]
					- PVtoBatt[ts] for ts in p.time_steps
		)
		r["to_load_series_kw"] = round.(value.(PVtoLoad), digits=3)
		Year1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_timestep)
		r["energy_produced_kwh"] = round(value(Year1PvProd), digits=0)
        d[t] = r
	end
    nothing
end


"""
    organize_multiple_pv_results(p::REoptInputs, d::Dict)

The last step in results processing: if more than one PV was modeled then move their results from the top
level keys (that use each PV.name) to an array of results with "PV" as the top key in the results dict `d`.
"""
function organize_multiple_pv_results(p::REoptInputs, d::Dict)
    if length(p.pvtechs) == 1
        return nothing
    end
    pvs = Dict[]
    for pvname in p.pvtechs
        d[pvname]["name"] = pvname  # add name to results dict to distinguish each PV
        push!(pvs, d[pvname])
        delete!(d, pvname)
    end
    d["PV"] = pvs
    nothing
end