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
`PV` results keys:
- `size_kw` Optimal PV capacity
- `lifecycle_om_cost_after_tax` Lifecycle operations and maintenance cost in present value, after tax
- `year_one_energy_produced_kwh` Energy produced over the first year
- `year_one_energy_produced_for_timed_pbi_kwh` Energy produced over the first year during timed_pbi hours (1-7pm)
- `annual_energy_produced_kwh` Average annual energy produced when accounting for degradation
- `lcoe_per_kwh` Levelized Cost of Energy produced by the PV system
- `electric_to_load_series_kw` Vector of power used to meet load over the first year
- `electric_to_storage_series_kw` Vector of power used to charge the battery over the first year
- `electric_to_grid_series_kw` Vector of power exported to the grid over the first year
- `electric_curtailed_series_kw` Vector of power curtailed over the first year
- `annual_energy_exported_kwh` Average annual energy exported to the grid
- `production_factor_series` PV production factor in each time step, either provided by user or obtained from PVWatts

!!! warn
    The key(s) used to access PV outputs in the results dictionary is determined by the `PV.name` value to allow for modeling multiple PV options. (The default `PV.name` is "PV".)

!!! note "Existing PV"
    All outputs account for any existing PV. E.g., `size_kw` includes existing capacity and the REopt-recommended additional capacity.  

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 
    
"""
function add_pv_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `PV` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    for t in p.techs.pv
        r = Dict{String, Any}()
        r["production_factor_series"] = p.production_factor[t, :]
		r["size_kw"] = round(value(m[Symbol("dvSize"*_n)][t]), digits=4)

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if !isempty(p.s.storage.types.elec)
			PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
		else
			PVtoBatt = repeat([0], length(p.time_steps))
		end
		r["electric_to_storage_series_kw"] = round.(value.(PVtoBatt), digits=3)

        r["electric_to_grid_series_kw"] = zeros(size(r["electric_to_storage_series_kw"]))
        r["annual_energy_exported_kwh"] = 0.0
        if !isempty(p.s.electric_tariff.export_bins)
            PVtoGrid = @expression(m, [ts in p.time_steps],
                    sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
            r["electric_to_grid_series_kw"] = round.(value.(PVtoGrid), digits=3).data

            r["annual_energy_exported_kwh"] = round(
                sum(r["electric_to_grid_series_kw"]) * p.hours_per_time_step, digits=0)
        end

		PVtoCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
		r["electric_curtailed_series_kw"] = round.(value.(PVtoCUR), digits=3)
		PVtoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
					- r["electric_curtailed_series_kw"][ts]
					- r["electric_to_grid_series_kw"][ts]
					- r["electric_to_storage_series_kw"][ts] for ts in p.time_steps
		)
		r["electric_to_load_series_kw"] = round.(value.(PVtoLoad), digits=3)
		Year1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_time_step)
		r["year_one_energy_produced_kwh"] = round(value(Year1PvProd), digits=0)
        r["annual_energy_produced_kwh"] = round(r["year_one_energy_produced_kwh"] * p.levelization_factor[t], digits=2)
		PVPerUnitSizeOMCosts = p.om_cost_per_kw[t] * p.pwf_om * m[Symbol("dvSize"*_n)][t]
		r["lifecycle_om_cost_after_tax"] = round(value(PVPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
        r["lcoe_per_kwh"] = calculate_lcoe(p, r, get_pv_by_name(t, p.s.pvs))

        # Determine time steps between 1-7pm 
        timed_pbi_time_steps = Int[]
        start_hr = 13 # 1pm
        end_hr = 19 # 7pm (noninclusive) (goes 1-7pm)
        datetime = DateTime(2017, 1, 1, 0) # starting at hour 0 because ts 1 = 12am = hour 0. Using 2017 bc not considering leap years
        for ts in time_steps
            hour = Hour(datetime).value
            if start_hr <= hour < end_hr
                push!(timed_pbi_time_steps, ts)
            end
            datetime += Dates.Hour(1)
        end

        # Note: Timed PBI only works with hourly analyses 
        TimedYear1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in timed_pbi_time_steps) * p.hours_per_time_step)
        r["year_one_energy_produced_for_timed_pbi_kwh"] = round(value(TimedYear1PvProd), digits=0)

        d[t] = r
	end
    nothing
end

"""
MPC `PV` results keys:
- `to_battery_series_kw`
- `to_grid_series_kw`
- `curtailed_production_series_kw`
- `to_load_series_kw`
- `energy_produced_kwh`
"""
function add_pv_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    for t in p.techs.pv
        r = Dict{String, Any}()

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if !isempty(p.s.storage.types.elec) 
			PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
            PVtoBatt = round.(value.(PVtoBatt), digits=3)
		else
			PVtoBatt = zeros(length(p.time_steps))
		end
        r["to_battery_series_kw"] = PVtoBatt

        r["to_grid_series_kw"] = zeros(length(p.time_steps))
        if !isempty(p.s.electric_tariff.export_bins)
            PVtoGrid = @expression(m, [ts in p.time_steps],
                    sum(m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for u in p.export_bins_by_tech[t]))
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
		Year1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_time_step)
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
    if length(p.techs.pv) == 1 && p.techs.pv[1] == "PV"
        return nothing
    end
    pvs = Dict[]
    for pvname in p.techs.pv
        d[pvname]["name"] = pvname  # add name to results dict to distinguish each PV
        push!(pvs, d[pvname])
        delete!(d, pvname)
    end
    d["PV"] = pvs
    nothing
end