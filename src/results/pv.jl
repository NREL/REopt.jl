# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`PV` results keys:
- `size_kw` Optimal PV DC capacity
- `lifecycle_om_cost_after_tax` Lifecycle operations and maintenance cost in present value, after tax
- `year_one_energy_produced_kwh` Energy produced over the first year
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
    @info "Starting add_pv_results"
    
    for t in p.techs.pv
        @info "Processing PV technology: $t"
        
        try
            r = Dict{String, Any}()
            r["production_factor_series"] = Vector(p.production_factor[t, :])
            @info "Got production factor series"
            
            r["size_kw"] = round(value(m[Symbol("dvSize"*_n)][t]), digits=4)
            @info "PV size_kw: $(r["size_kw"])"

            # Battery storage calculations
            PVtoBatt = if !isempty(p.s.storage.types.elec)
                @info "Calculating storage-related values"
                (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
            else
                @info "No electric storage, using zeros"
                zeros(length(p.time_steps))
            end
            PVtoBatt = round.(value.(PVtoBatt), digits=3)
            r["electric_to_storage_series_kw"] = PVtoBatt

            # Grid export calculations
            r["electric_to_grid_series_kw"] = zeros(length(p.time_steps))
            r["annual_energy_exported_kwh"] = 0.0
            if !isempty(p.s.electric_tariff.export_bins)
                @info "Calculating grid export values"
                PVtoGrid = @expression(m, [ts in p.time_steps],
                        sum(m[:dvProductionToGrid][t, u, ts] for u in p.export_bins_by_tech[t]))
                r["electric_to_grid_series_kw"] = round.(value.(PVtoGrid), digits=3).data
                r["annual_energy_exported_kwh"] = round(
                    sum(r["electric_to_grid_series_kw"]) * p.hours_per_time_step, digits=0)
            end

            # Curtailment calculations
            PVtoCUR = (m[Symbol("dvCurtail"*_n)][t, ts] for ts in p.time_steps)
            r["electric_curtailed_series_kw"] = round.(value.(PVtoCUR), digits=3)

            # Load consumption calculations
            PVtoLoad = (m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
                        - r["electric_curtailed_series_kw"][ts]
                        - r["electric_to_grid_series_kw"][ts]
                        - r["electric_to_storage_series_kw"][ts] for ts in p.time_steps
            )
            r["electric_to_load_series_kw"] = round.(value.(PVtoLoad), digits=3)

            # Energy production calculations
            Year1PvProd = (sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_time_step)
            r["year_one_energy_produced_kwh"] = round(value(Year1PvProd), digits=0)
            r["annual_energy_produced_kwh"] = round(r["year_one_energy_produced_kwh"] * p.levelization_factor[t], digits=2)

            pv_tech = get_pv_by_name(t, p.s.pvs)
            if r["annual_energy_produced_kwh"] > 0
                r["lcoe_per_kwh"] = calculate_lcoe(p, r, pv_tech)
            else
                @warn "No energy production for PV technology $t, setting LCOE to NaN"
                r["lcoe_per_kwh"] = NaN
            end

            d[t] = r
            
        catch e
            @error "Error processing PV technology $t" exception=(e, catch_backtrace())
            rethrow(e)
        end
    end
    
    @info "Completed add_pv_results"
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
    @info "Starting add_pv_results"
    
    for t in p.techs.pv
        @info "Processing PV tech: $t"
        r = Dict{String, Any}()
        
        try
            r["production_factor_series"] = Vector(p.production_factor[t, :])
            @info "Got production factor series"
            
            r["size_kw"] = round(value(m[Symbol("dvSize"*_n)][t]), digits=4)
            @info "PV size_kw: $(r["size_kw"])"

            # Storage calculations
            if !isempty(p.s.storage.types.elec)
                @info "Calculating storage-related values"
                PVtoBatt = (sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) for ts in p.time_steps)
            else
                @info "No electric storage, using zeros"
                PVtoBatt = repeat([0], length(p.time_steps))
            end
            r["electric_to_storage_series_kw"] = round.(value.(PVtoBatt), digits=3)
            
            # Rest of the existing function with debug statements...
            
        catch e
            @error "Error processing PV tech $t" exception=(e, catch_backtrace())
            rethrow(e)
        end
        
        @info "Completed processing for PV tech: $t"
        d[t] = r
    end
    @info "Completed add_pv_results"
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