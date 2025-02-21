# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`PV` results keys:
- `size_kw` Optimal PV DC capacity
- `lifecycle_om_cost_after_tax` Lifecycle operations and maintenance cost in present value, after tax
- `year_one_energy_produced_kwh` Energy produced over the first year
- `annual_energy_produced_kwh` Average annual energy produced when accounting for degradation
- `lcoe_per_kwh` Levelized Cost of Energy produced by the PV system
- `electric_to_load_series_kw` Vector of power used to meet load over an average year
- `electric_to_storage_series_kw` Vector of power used to charge the battery over an average year
- `electric_to_grid_series_kw` Vector of power exported to the grid over an average year
- `electric_curtailed_series_kw` Vector of power curtailed over an average year
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
        r["production_factor_series"] = Vector(p.production_factor[t, :])
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
		PVPerUnitSizeOMCosts = p.third_party_factor * p.om_cost_per_kw[t] * p.pwf_om * m[Symbol("dvSize"*_n)][t]
		r["lifecycle_om_cost_after_tax"] = round(value(PVPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
        r["lcoe_per_kwh"] = calculate_lcoe(p, r, get_pv_by_name(t, p.s.pvs))
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