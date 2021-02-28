function add_pv_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    for t in p.pvtechs
        r = Dict{String, Any}()
		r["size_kw"] = round(value(m[Symbol("dvSize"*_n)][t]), digits=4)

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if !isempty(p.storage.types)
			PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.storage.types) for ts in p.time_steps)
		else
			PVtoBatt = repeat([0], length(p.time_steps))
		end
		r["year_one_to_battery_series_kw"] = round.(value.(PVtoBatt), digits=3)

		PVtoNEM = (m[Symbol("dvNEMexport"*_n)][t, ts] for ts in p.time_steps)
		r[string(t, "toNEM")] = round.(value.(PVtoNEM), digits=3)

		PVtoWHL = (m[Symbol("dvWHLexport"*_n)][t, ts] for ts in p.time_steps)
		r[string(t, "toWHL")] = round.(value.(PVtoWHL), digits=3)

        r["year_one_to_grid_series_kw"] = r[string(t, "toWHL")] .+ r[string(t, "toNEM")]

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
		PVPerUnitSizeOMCosts = p.om_cost_per_kw[t] * p.pwf_om * m[Symbol("dvSize"*_n)][t]
		r["total_om_cost_us_dollars"] = round(value(PVPerUnitSizeOMCosts) * (1 - p.owner_tax_pct), digits=0)
        d[t] = r
	end
    nothing
end