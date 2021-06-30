


function add_variables!(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	reopt_nodes = [rs.node for rs in ps]
	
	dvs_idx_on_techs = String[
		"dvSize",
		"dvPurchaseSize",
	]
	dvs_idx_on_techs_timesteps = String[
        "dvCurtail",
		"dvRatedProduction",
	]
	dvs_idx_on_storagetypes = String[
		"dvStoragePower",
		"dvStorageEnergy",
	]
	dvs_idx_on_storagetypes_timesteps = String[
		"dvDischargeFromStorage",
		"dvGridToStorage",
	]
	for p in ps
		_n = string("_", p.node)
		for dv in dvs_idx_on_techs
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.techs], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_techs_timesteps
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.techs, p.time_steps], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_storagetypes
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.storage.types], base_name=x, lower_bound=0)
		end

		for dv in dvs_idx_on_storagetypes_timesteps
			x = dv*_n
			m[Symbol(x)] = @variable(m, [p.storage.types, p.time_steps], base_name=x, lower_bound=0)
		end

		dv = "dvGridPurchase"*_n
		m[Symbol(dv)] = @variable(m, [p.time_steps], base_name=dv, lower_bound=0)

		dv = "dvPeakDemandTOU"*_n
		m[Symbol(dv)] = @variable(m, [p.ratchets], base_name=dv, lower_bound=0)

		dv = "dvPeakDemandMonth"*_n
		m[Symbol(dv)] = @variable(m, [p.months], base_name=dv, lower_bound=0)

		dv = "dvProductionToStorage"*_n
		m[Symbol(dv)] = @variable(m, [p.storage.types, p.techs, p.time_steps], base_name=dv, lower_bound=0)

		dv = "dvStoredEnergy"*_n
		m[Symbol(dv)] = @variable(m, [p.storage.types, 0:p.time_steps[end]], base_name=dv, lower_bound=0)

		dv = "MinChargeAdder"*_n
		m[Symbol(dv)] = @variable(m, base_name=dv, lower_bound=0)

        if !isempty(p.etariff.export_bins)
            dv = "dvProductionToGrid"*_n
            m[Symbol(dv)] = @variable(m, [p.elec_techs, p.etariff.export_bins, p.time_steps], base_name=dv, lower_bound=0)
        end

		ex_name = "TotalTechCapCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.two_party_factor *
			sum( p.cap_cost_slope[t] * m[Symbol("dvPurchaseSize"*_n)][t] for t in p.techs ) 
		)

		ex_name = "TotalStorageCapCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.two_party_factor * 
			sum(  p.storage.cost_per_kw[b] * m[Symbol("dvStoragePower"*_n)][b] 
				+ p.storage.cost_per_kwh[b] * m[Symbol("dvStorageEnergy"*_n)][b] for b in p.storage.types )
		)

		ex_name = "TotalPerUnitSizeOMCosts"*_n
		m[Symbol(ex_name)] = @expression(m, p.two_party_factor * p.pwf_om * 
			sum( p.om_cost_per_kw[t] * m[Symbol("dvSize"*_n)][t] for t in p.techs ) 
		)
	
		add_elec_utility_expressions(m, p; _n=_n)
	
		#################################  Objective Function   ########################################
		m[Symbol("Costs"*_n)] = @expression(m,
			# Capital Costs
			m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)] +  
			
			## Fixed O&M, tax deductible for owner
			m[Symbol("TotalPerUnitSizeOMCosts"*_n)] * (1 - p.owner_tax_pct) +
	
			# Utility Bill, tax deductible for offtaker, including export benefit
			m[Symbol("TotalElecBill"*_n)] * (1 - p.offtaker_tax_pct)
		);
    end
    add_bounds(m, ps)
end


"""
add non-negative bounds to decision variables
"""
function add_bounds(m::JuMP.AbstractModel, ps::Array{REoptInputs})
    
	reopt_nodes = [rs.node for rs in ps]
	
	dvs_idx_on_techs = String[
		"dvSize",
		"dvPurchaseSize",
	]
	dvs_idx_on_techs_timesteps = String[
        "dvCurtail",
		"dvRatedProduction",
	]
	dvs_idx_on_storagetypes = String[
		"dvStoragePower",
		"dvStorageEnergy",
	]
	dvs_idx_on_storagetypes_timesteps = String[
		"dvDischargeFromStorage",
		"dvGridToStorage",
	]
	for p in ps
        _n = string("_", p.node)
        
		for dv in dvs_idx_on_techs
			x = dv*_n
			@constraint(m, [tech in p.techs], -m[Symbol(x)][tech] ≤ 0 )
		end

		for dv in dvs_idx_on_techs_timesteps
			x = dv*_n
            @constraint(m, [tech in p.techs, ts in p.time_steps], 
                -m[Symbol(x)][tech, ts] ≤ 0
            )
		end

		for dv in dvs_idx_on_storagetypes
			x = dv*_n
            @constraint(m, [b in p.storage.types], 
                -m[Symbol(x)][b] ≤ 0
            )
		end

		for dv in dvs_idx_on_storagetypes_timesteps
			x = dv*_n
            @constraint(m, [b in p.storage.types, ts in p.time_steps], 
                -m[Symbol(x)][b, ts] ≤ 0
            )
		end

		dv = "dvGridPurchase"*_n
		@constraint(m, [ts in p.time_steps], -m[Symbol(dv)][ts] ≤ 0)

		dv = "dvPeakDemandTOU"*_n
		@constraint(m, [r in p.ratchets], -m[Symbol(dv)][r] ≤ 0)

		dv = "dvPeakDemandMonth"*_n
		@constraint(m, [mth in p.months], -m[Symbol(dv)][mth] ≤ 0)

		dv = "dvProductionToStorage"*_n
        @constraint(m, [b in p.storage.types, tech in p.techs, ts in p.time_steps], 
            -m[Symbol(dv)][b, tech, ts] ≤ 0
        )

		dv = "dvStoredEnergy"*_n
        @constraint(m, [b in p.storage.types, ts in 0:p.time_steps[end]], 
            -m[Symbol(dv)][b, ts] ≤ 0
        )

		dv = "MinChargeAdder"*_n
		@constraint(m, -m[Symbol(dv)] ≤ 0)
    end
end


function build_reopt!(m::JuMP.AbstractModel, ps::Array{REoptInputs})
    add_variables!(m, ps)
    @warn "Outages are not currently modeled in multinode mode."
    @warn "Diesel generators are not currently modeled in multinode mode."
    for p in ps
        _n = string("_", p.node)

        for b in p.storage.types
            if p.storage.max_kw[b] == 0 || p.storage.max_kwh[b] == 0
                @constraint(m, [ts in p.time_steps], m[Symbol("dvStoredEnergy"*_n)][b, ts] == 0)
                @constraint(m, m[Symbol("dvStorageEnergy"*_n)][b] == 0)
                @constraint(m, m[Symbol("dvStoragePower"*_n)][b] == 0)
                @constraint(m, [t in p.elec_techs, ts in p.time_steps_with_grid],
                            m[Symbol("dvProductionToStorage"*_n)][b, t, ts] == 0)
                @constraint(m, [ts in p.time_steps], m[Symbol("dvDischargeFromStorage"*_n)][b, ts] == 0)
                @constraint(m, [ts in p.time_steps], m[Symbol("dvGridToStorage"*_n)][b, ts] == 0)
            else
                add_storage_size_constraints(m, p, b; _n=_n)
                add_storage_dispatch_constraints(m, p, b; _n=_n)
            end
        end

        if any(max_kw->max_kw > 0, (p.storage.max_kw[b] for b in p.storage.types))
            add_storage_sum_constraints(m, p; _n=_n)
        end
    
        add_production_constraints(m, p; _n=_n)
    
        if !isempty(p.techs)
            add_tech_size_constraints(m, p; _n=_n)
        end
    
        add_load_balance_constraints(m, p; _n=_n)
    
        if !isempty(p.etariff.export_bins)
            add_export_constraints(m, p; _n=_n)
        end
    
        if !isempty(p.etariff.time_steps_monthly)
            add_monthly_peak_constraint(m, p; _n=_n)
        end
    
        if !isempty(p.etariff.tou_demand_ratchet_timesteps)
            add_tou_peak_constraint(m, p; _n=_n)
        end

		if !(p.elecutil.allow_simultaneous_export_import) & !isempty(p.etariff.export_bins)
			add_simultaneous_export_import_constraint(m, p; _n=_n)
		end
    
    end
end


function add_objective!(m::JuMP.AbstractModel, ps::Array{REoptInputs}; obj::Int=2)
	if obj == 1
		@objective(m, Min, sum(m[Symbol(string("Costs_", p.node))] for p in ps))
	elseif obj == 2  # Keep SOC high
		@objective(m, Min, sum(m[Symbol(string("Costs_", p.node))] for p in ps)
        - sum(sum(m[Symbol(string("dvStoredEnergy_", p.node))][:elec, ts] 
            for ts in p.time_steps) for p in ps) / (8760. / ps[1].hours_per_timestep))
	end  # TODO need to handle different hours_per_timestep?
	nothing
end


function run_reopt(m::JuMP.AbstractModel, ps::Array{REoptInputs}; obj::Int=2)

	build_reopt!(m, ps)

	add_objective!(m, ps; obj)

	@info "Model built. Optimizing..."
	tstart = time()
	optimize!(m)
	opt_time = round(time() - tstart, digits=3)
	if termination_status(m) == MOI.TIME_LIMIT
		status = "timed-out"
    elseif termination_status(m) == MOI.OPTIMAL
        status = "optimal"
    else
        status = "not optimal"
        @warn "REopt solved with " termination_status(m), ", returning the model."
        return m
	end
	@info "REopt solved with " termination_status(m)
	@info "Solving took $(opt_time) seconds."
    
	tstart = time()
	results = reopt_results(m, ps)
	time_elapsed = time() - tstart
	@info "Total results processing took $(round(time_elapsed, digits=3)) seconds."
	results["status"] = status
	results["solver_seconds"] = opt_time
	return results
end


function reopt_results(m::JuMP.AbstractModel, ps::Array{REoptInputs})
	# TODO address Warning: The addition operator has been used on JuMP expressions a large number of times.
	results = Dict{Union{Int, String}, Any}()
	for p in ps
		results[p.node] = reopt_results(m, p; _n=string("_", p.node))
	end
	return results
end

