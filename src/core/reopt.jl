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
import MathOptInterface
const MOI = MathOptInterface


function run_reopt(REopt::JuMP.AbstractModel, fp::String)
	s = Scenario(JSON.parsefile(fp))
	run_reopt(REopt, REoptInputs(s))
end


function run_reopt(REopt::JuMP.AbstractModel, d::Dict)
	s = Scenario(d)
	run_reopt(REopt, REoptInputs(s))
end


"""
	function build_reopt!(m::JuMP.AbstractModel, fp::String
		; lpf::Union{Nothing, JuMP.AbstractModel}=nothing
	)
Add variables and constraints for REopt model. optional lpf model is for bilevel problems where the
	exported power in each time step is a decision variable in the linear power flow problem (lpf).
	fp is used to load in JSON file to construct REoptInputs.
"""
function build_reopt!(m::JuMP.AbstractModel, fp::String)
	s = Scenario(JSON.parsefile(fp))
	build_reopt!(m, REoptInputs(s))
	nothing
end


"""
	function build_reopt!(m::JuMP.AbstractModel, p::REoptInputs
		; lpf::Union{Nothing, JuMP.AbstractModel}=nothing
	)
Add variables and constraints for REopt m. optional lpf m is for bilevel problems where the
	exported power in each time step is a decision variable in the linear power flow problem (lpf).
"""
function build_reopt!(m::JuMP.AbstractModel, p::REoptInputs)

	add_variables!(m, p)

    ##############################################################################
	#############  		Constraints									 #############
	##############################################################################

	## Temporary workaround for outages time_steps_without_grid
	for ts in p.time_steps_without_grid

		fix(m[:dvGridPurchase][ts], 0.0, force=true)

		for t in p.storage.types
			fix(m[:dvGridToStorage][t, ts], 0.0, force=true)
		end

		for t in p.techs
			fix(m[:dvNEMexport][t, ts], 0.0, force=true)
			fix(m[:dvWHLexport][t, ts], 0.0, force=true)
		end
	end

	for b in p.storage.types
		if p.storage.max_kw[b] == 0 || p.storage.max_kwh[b] == 0
			@constraint(m, [ts in p.time_steps], m[:dvStoredEnergy][b, ts] == 0)
			@constraint(m, m[:dvStorageEnergy][b] == 0)
			@constraint(m, m[:dvStoragePower][b] == 0)
			@constraint(m, [t in p.elec_techs, ts in p.time_steps_with_grid],
						m[:dvProductionToStorage][b, t, ts] == 0)
			@constraint(m, [ts in p.time_steps], m[:dvDischargeFromStorage][b, ts] == 0)
			@constraint(m, [ts in p.time_steps], m[:dvGridToStorage][b, ts] == 0)
			@constraint(m, [u in p.storage.export_bins, ts in p.time_steps],
						m[:dvStorageExport][b, u, ts] == 0)
		else
			add_storage_size_constraints(m, p, b)
			add_storage_dispatch_constraints(m, p, b)
		end
	end

	if !isempty(p.gentechs)
		add_fuel_burn_constraints(m,p)
		add_binGenIsOnInTS_constraints(m,p)
		add_gen_can_run_constraints(m,p)
		add_gen_rated_prod_constraint(m,p)
	end

	if any(max_kw->max_kw > 0, (p.storage.max_kw[b] for b in p.storage.types))
		add_storage_sum_constraints(m, p)
	end

	add_production_constraints(m, p)

	if !isempty(p.techs)
		add_tech_size_constraints(m, p)
	end

	add_load_balance_constraints(m, p)

	if !isempty(p.etariff.export_bins)
		add_export_constraints(m, p)
	end

	if !isempty(p.etariff.time_steps_monthly)
		add_monthly_peak_constraint(m, p)
	end

	if !isempty(p.etariff.tou_demand_ratchet_timesteps)
		add_tou_peak_constraint(m, p)
	end

	@expression(m, TotalTechCapCosts, p.two_party_factor *
		sum( p.cap_cost_slope[t] * m[:dvPurchaseSize][t] for t in p.techs )  # TODO add Yintercept and binary
	)
	
	@expression(m, TotalStorageCapCosts, p.two_party_factor *
		sum(  p.storage.cost_per_kw[b] * m[:dvStoragePower][b]
			+ p.storage.cost_per_kwh[b] * m[:dvStorageEnergy][b] for b in p.storage.types )
	)
	
	@expression(m, TotalPerUnitSizeOMCosts, p.two_party_factor * p.pwf_om *
		sum( p.om_cost_per_kw[t] * m[:dvSize][t] for t in p.techs )
	)
	
    if !isempty(p.gentechs)
		m[:TotalPerUnitProdOMCosts] = @expression(m, p.two_party_factor * p.pwf_om *
			sum(p.generator.om_cost_per_kwh * p.hours_per_timestep *
			m[:dvRatedProduction][t, ts] for t in p.gentechs, ts in p.time_steps)
		)
		m[:TotalGenFuelCharges] = @expression(m, p.pwf_e *
			sum(m[:dvFuelUsage][t,ts] * p.generator.fuel_cost_per_gallon for t in p.gentechs, ts in p.time_steps)
		)
    else
		m[:TotalPerUnitProdOMCosts] = 0.0
		m[:TotalGenFuelCharges] = 0.0
	end

	if !isempty(p.techs)
		# NOTE: levelization_factor is baked into dvNEMexport, dvWHLexport
		@expression(m, TotalExportBenefit, p.pwf_e * p.hours_per_timestep * sum(
			sum( p.etariff.export_rates[u][ts] * m[:dvStorageExport][b,u,ts] for b in p.storage.can_grid_charge, u in p.storage.export_bins)
		  + sum( p.etariff.export_rates[:NEM][ts] * m[:dvNEMexport][t, ts] for t in p.techs)
		  + sum( p.etariff.export_rates[:WHL][ts] * m[:dvWHLexport][t, ts]  for t in p.techs)
			for ts in p.time_steps )
		)
		@expression(m, ExportBenefitYr1, TotalExportBenefit / p.pwf_e)
	else
		@expression(m, TotalExportBenefit, 0)
		@expression(m, ExportBenefitYr1, 0)
	end

	if !isempty(p.elecutil.outage_durations)
		add_dv_UnservedLoad_constraints(m,p)
		add_outage_cost_constraints(m,p)
		add_MG_production_constraints(m,p)
		add_MG_storage_dispatch_constraints(m,p)
		add_cannot_have_MG_with_only_PVwind_constraints(m,p)
		add_MG_size_constraints(m,p)
		
		if !isempty(p.gentechs)
			add_MG_fuel_burn_constraints(m,p)
			add_binMGGenIsOnInTS_constraints(m,p)
		else
			m[:ExpectedMGFuelUsed] = 0
			m[:ExpectedMGFuelCost] = 0
			@constraint(m, [s in p.elecutil.scenarios, tz in p.elecutil.outage_start_timesteps, ts in p.elecutil.outage_timesteps],
				m[:binMGGenIsOnInTS][s, tz, ts] == 0
			)
		end
		
		if p.min_resil_timesteps > 0
			add_min_hours_crit_ld_met_constraint(m,p)
		end
	end


	@expression(m, TotalEnergyChargesUtil, p.pwf_e * p.hours_per_timestep *
		sum( p.etariff.energy_rates[ts] * m[:dvGridPurchase][ts] for ts in p.time_steps)
	)

	if !isempty(p.etariff.tou_demand_rates)
		@expression(m, DemandTOUCharges, p.pwf_e * sum( p.etariff.tou_demand_rates[r] * m[:dvPeakDemandTOU][r] for r in p.ratchets) )
	else
		@expression(m, DemandTOUCharges, 0)
	end

	if !isempty(p.etariff.monthly_demand_rates)
		@expression(m, DemandFlatCharges, p.pwf_e * sum( p.etariff.monthly_demand_rates[mth] * m[:dvPeakDemandMonth][mth] for mth in p.months) )
	else
		@expression(m, DemandFlatCharges, 0)
	end
	@expression(m, TotalDemandCharges, DemandTOUCharges + DemandFlatCharges)
	@expression(m, TotalFixedCharges, p.pwf_e * p.etariff.fixed_monthly_charge * 12)

	if p.etariff.annual_min_charge > 12 * p.etariff.min_monthly_charge
        TotalMinCharge = p.etariff.annual_min_charge
    else
        TotalMinCharge = 12 * p.etariff.min_monthly_charge
    end

	if TotalMinCharge >= 1e-2
		add_mincharge_constraint(m, p)
	else
		@constraint(m, MinChargeAddCon, m[:MinChargeAdder] == 0)
	end

	#################################  Objective Function   ########################################
	@expression(m, Costs,
		# Capital Costs
		TotalTechCapCosts + TotalStorageCapCosts +

		# Fixed O&M, tax deductible for owner
		TotalPerUnitSizeOMCosts * (1 - p.owner_tax_pct) +

		# Variable O&M, tax deductible for owner
		m[:TotalPerUnitProdOMCosts] * (1 - p.owner_tax_pct) +

		# Total Generator Fuel Costs, tax deductible for offtaker
        m[:TotalGenFuelCharges] * (1 - p.offtaker_tax_pct) +

		# Utility Bill, tax deductible for offtaker
		(TotalEnergyChargesUtil + TotalDemandCharges + TotalExportBenefit + TotalFixedCharges + 0.999 * m[:MinChargeAdder]) * (1 - p.offtaker_tax_pct)
	);
	if !isempty(p.elecutil.outage_durations)
		add_to_expression!(Costs, m[:ExpectedOutageCost] + m[:mgTotalTechUpgradeCost] + m[:dvMGStorageUpgradeCost] + m[:ExpectedMGFuelCost])
	end
    #= Note: 0.9999*MinChargeAdder in Objective b/c when TotalMinCharge > (TotalEnergyCharges + TotalDemandCharges + TotalExportBenefit + TotalFixedCharges)
		it is arbitrary where the min charge ends up (eg. could be in TotalDemandCharges or MinChargeAdder).
		0.0001*MinChargeAdder is added back into LCC when writing to results.  =#
	nothing
end


function run_reopt(m::JuMP.AbstractModel, p::REoptInputs; obj::Int=2)

	build_reopt!(m, p)

	if obj == 1
		@objective(m, Min, m[:Costs])
	elseif obj == 2  # Keep SOC high
		@objective(m, Min, m[:Costs] - sum(m[:dvStoredEnergy][:elec, ts] for ts in p.time_steps) /
									   (8760. / p.hours_per_timestep)
		)
	end

	@info "Model built. Optimizing..."
	tstart = time()
	optimize!(m)
	time_elapsed = time() - tstart
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
	@info "Solving took $(round(time_elapsed, digits=3)) seconds."

	tstart = time()
	results = reopt_results(m, p)
	time_elapsed = time() - tstart
	@info "Total results processing took $(round(time_elapsed, digits=3)) seconds."
	results["status"] = status
	results["inputs"] = p
	return results
end


function reopt_results(m::JuMP.AbstractModel, p::REoptInputs; _n="")

	tstart = time()
    @expression(m, Year1UtilityEnergy,  p.hours_per_timestep * sum(
		m[:dvGridPurchase][ts] for ts in p.time_steps)
	)
    Year1EnergyCost = m[:TotalEnergyChargesUtil] / p.pwf_e
    Year1DemandCost = m[:TotalDemandCharges] / p.pwf_e
    Year1DemandTOUCost = m[:DemandTOUCharges] / p.pwf_e
    Year1DemandFlatCost = m[:DemandFlatCharges] / p.pwf_e
    Year1FixedCharges = m[:TotalFixedCharges] / p.pwf_e
    Year1MinCharges = m[:MinChargeAdder] / p.pwf_e
    Year1Bill = Year1EnergyCost + Year1DemandCost + Year1FixedCharges + Year1MinCharges

    results = Dict{String, Any}("batt_kwh" => value(m[:dvStorageEnergy][:elec]))
    results["batt_kw"] = value(m[:dvStoragePower][:elec])
	results["lcc"] = round(value(m[Symbol("Costs"*_n)]) + 0.0001 * value(m[Symbol("MinChargeAdder"*_n)]))

    if results["batt_kwh"] != 0
    	soc = (m[:dvStoredEnergy][:elec, ts] for ts in p.time_steps)
        results["year_one_soc_series_pct"] = value.(soc) ./ results["batt_kwh"]
    else
        results["year_one_soc_series_pct"] = []
    end

    net_capital_costs_plus_om = value(m[:TotalTechCapCosts] + m[:TotalStorageCapCosts]) +
                                value(m[:TotalPerUnitSizeOMCosts]) * (1 - p.owner_tax_pct)

    push!(results, Dict("year_one_utility_kwh" => round(value(Year1UtilityEnergy), digits=2),
						 "year_one_energy_cost" => round(value(Year1EnergyCost), digits=2),
						 "year_one_demand_cost" => round(value(Year1DemandCost), digits=2),
						 "year_one_demand_tou_cost" => round(value(Year1DemandTOUCost), digits=2),
						 "year_one_demand_flat_cost" => round(value(Year1DemandFlatCost), digits=2),
						 "year_one_export_benefit" => round(value(m[:ExportBenefitYr1]), digits=0),
						 "year_one_fixed_cost" => round(Year1FixedCharges, digits=0),
						 "year_one_min_charge_adder" => round(value(Year1MinCharges), digits=2),
						 "year_one_bill" => round(value(Year1Bill), digits=2),
						 "total_energy_cost" => round(value(m[:TotalEnergyChargesUtil]) * (1 - p.offtaker_tax_pct), digits=2),
						 "total_demand_cost" => round(value(m[:TotalDemandCharges]) * (1 - p.offtaker_tax_pct), digits=2),
						 "total_fixed_cost" => round(m[:TotalFixedCharges] * (1 - p.offtaker_tax_pct), digits=2),
						 "total_export_benefit" => -1 * round(value(m[:TotalExportBenefit]) * (1 - p.offtaker_tax_pct), digits=2),
						 "total_min_charge_adder" => round(value(m[:MinChargeAdder]) * (1 - p.offtaker_tax_pct), digits=2),
						 "net_capital_costs_plus_om" => round(net_capital_costs_plus_om, digits=0),
						 "net_capital_costs" => round(value(m[:TotalTechCapCosts] + m[:TotalStorageCapCosts]), digits=2))...)

    GridToBatt = (sum(m[:dvGridToStorage][b, ts] for b in p.storage.types) for ts in p.time_steps)
    results["GridToBatt"] = round.(value.(GridToBatt), digits=3)

	GridToLoad = (m[:dvGridPurchase][ts] - sum(m[:dvGridToStorage][b, ts] for b in p.storage.types) for ts in p.time_steps)
    results["GridToLoad"] = round.(value.(GridToLoad), digits=3)

	if !isempty(p.pvtechs)
    for t in p.pvtechs

		results[string(t, "_kw")] = round(value(m[:dvSize][t]), digits=4)

		# NOTE: must use anonymous expressions in this loop to overwrite values for cases with multiple PV
		if !isempty(p.storage.types)
			PVtoBatt = (sum(m[:dvProductionToStorage][b, t, ts] for b in p.storage.types) for ts in p.time_steps)
		else
			PVtoBatt = repeat([0], length(p.time_steps))
		end
		results[string(t, "toBatt")] = round.(value.(PVtoBatt), digits=3)

		PVtoNEM = (m[:dvNEMexport][t, ts] for ts in p.time_steps)
		results[string(t, "toNEM")] = round.(value.(PVtoNEM), digits=3)

		PVtoWHL = (m[:dvWHLexport][t, ts] for ts in p.time_steps)
		results[string(t, "toWHL")] = round.(value.(PVtoWHL), digits=3)

		PVtoCUR = (m[:dvCurtail][t, ts] for ts in p.time_steps)
		results[string(t, "toCUR")] = round.(value.(PVtoCUR), digits=3)

		PVtoLoad = (m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
					- results[string(t, "toCUR")][ts]
					- results[string(t, "toWHL")][ts]
					- results[string(t, "toNEM")][ts]
					- results[string(t, "toBatt")][ts] for ts in p.time_steps
		)
		results[string(t, "toLoad")] = round.(value.(PVtoLoad), digits=3)

		Year1PvProd = (sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts] for ts in p.time_steps) * p.hours_per_timestep)
		results[string("year_one_energy_produced_", t)] = round(value(Year1PvProd), digits=0)

		PVPerUnitSizeOMCosts = p.om_cost_per_kw[t] * p.pwf_om * m[:dvSize][t]
		results[string(t, "_net_fixed_om_costs")] = round(value(PVPerUnitSizeOMCosts) * (1 - p.owner_tax_pct), digits=0)
	end
	end
	
	time_elapsed = time() - tstart
	@info "Base results processing took $(round(time_elapsed, digits=3)) seconds."
	
	tstart = time()
	if !isempty(p.gentechs)
		add_generator_results(m, p, results)
	end
	time_elapsed = time() - tstart
	@info "Generator results processing took $(round(time_elapsed, digits=3)) seconds."
	
	tstart = time()
	if !isempty(p.elecutil.outage_durations)
		add_outage_results(m, p, results)
	end
	time_elapsed = time() - tstart
	@info "Outage results processing took $(round(time_elapsed, digits=3)) seconds."
	return results
end


function add_variables!(m::JuMP.AbstractModel, p::REoptInputs)
	@variables m begin
		dvWHLexport[p.techs, p.time_steps] >= 0  # [kW]
		dvSize[p.techs] >= 0  # System Size of Technology t [kW]
		dvPurchaseSize[p.techs] >= 0  # system kW beyond existing_kw that must be purchased
		dvGridPurchase[p.time_steps] >= 0  # Power from grid dispatched to meet electrical load [kW]
		dvRatedProduction[p.techs, p.time_steps] >= 0  # Rated production of technology t [kW]
		dvNEMexport[p.techs, p.time_steps] >= 0  # [kW]
		dvCurtail[p.techs, p.time_steps] >= 0  # [kW]
		dvProductionToStorage[p.storage.types, p.techs, p.time_steps] >= 0  # Power from technology t used to charge storage system b [kW]
		dvDischargeFromStorage[p.storage.types, p.time_steps] >= 0 # Power discharged from storage system b [kW]
		dvGridToStorage[p.storage.types, p.time_steps] >= 0 # Electrical power delivered to storage by the grid [kW]
		dvStoredEnergy[p.storage.types, 0:p.time_steps[end]] >= 0  # State of charge of storage system b
		dvStoragePower[p.storage.types] >= 0   # Power capacity of storage system b [kW]
		dvStorageEnergy[p.storage.types] >= 0   # Energy capacity of storage system b [kWh]
		dvStorageExport[p.storage.types, p.storage.export_bins, p.time_steps] >= 0  # storage to the grid or curtail [kW]
		dvPeakDemandTOU[p.ratchets] >= 0  # Peak electrical power demand during ratchet r [kW]
		dvPeakDemandMonth[p.months] >= 0  # Peak electrical power demand during month m [kW]
		MinChargeAdder >= 0
	end

	if !isempty(p.gentechs)  # Problem becomes a MILP
		@variables m begin
			dvFuelUsage[p.gentechs, p.time_steps] >= 0 # Fuel burned by technology t in each time step
			binGenIsOnInTS[p.gentechs, p.time_steps], Bin  # 1 If technology t is operating in time step h; 0 otherwise
		end
	end

	if !isempty(p.elecutil.outage_durations) # add dvUnserved Load if there is at least one outage
		max_outage_duration = maximum(p.elecutil.outage_durations)
		outage_timesteps = p.elecutil.outage_timesteps
		tZeros = p.elecutil.outage_start_timesteps
		S = p.elecutil.scenarios
		# TODO: currently defining more decision variables than necessary b/c using rectangular arrays, could use dicts of decision variables instead
		@variables m begin # if there is more than one specified outage, there can be more othan one outage start time
			dvUnservedLoad[S, tZeros, outage_timesteps] >= 0 # unserved load not met by system
			dvMGProductionToStorage[p.techs, S, tZeros, outage_timesteps] >= 0 # Electricity going to the storage system during each timestep
			dvMGDischargeFromStorage[S, tZeros, outage_timesteps] >= 0 # Electricity coming from the storage system during each timestep
			dvMGRatedProduction[p.techs, S, tZeros, outage_timesteps]  # MG Rated Production at every timestep.  Multiply by ProdFactor to get actual energy
			dvMGStoredEnergy[S, tZeros, 0:max_outage_duration] >= 0 # State of charge of the MG storage system
			dvMaxOutageCost[S] >= 0 # maximum outage cost dependent on number of outage durations
			dvMGTechUpgradeCost[p.techs] >= 0
			dvMGStorageUpgradeCost >= 0
			dvMGsize[p.techs] >= 0
			
			dvMGFuelUsed[p.techs, S, tZeros] >= 0
			dvMGMaxFuelUsage[S] >= 0
			dvMGMaxFuelCost[S] >= 0
			dvMGCurtail[p.techs, S, tZeros, outage_timesteps] >= 0

			binMGStorageUsed, Bin # 1 if MG storage battery used, 0 otherwise
			binMGTechUsed[p.techs], Bin # 1 if MG tech used, 0 otherwise
			binMGGenIsOnInTS[S, tZeros, outage_timesteps], Bin
		end
	end

end


function add_generator_results(m, p, r::Dict)
	GenPerUnitSizeOMCosts = @expression(m, p.two_party_factor * p.pwf_om * sum(m[:dvSize][t] * p.om_cost_per_kw[t] for t in p.gentechs))

	GenPerUnitProdOMCosts = @expression(m, p.two_party_factor * p.pwf_om * p.hours_per_timestep *
		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.generator.om_cost_per_kwh
			for t in p.gentechs, ts in p.time_steps)
	)
	r["generator_kw"] = value(sum(m[:dvSize][t] for t in p.gentechs))
	r["gen_net_fixed_om_costs"] = round(value(GenPerUnitSizeOMCosts) * (1 - p.owner_tax_pct), digits=0)
	r["gen_net_variable_om_costs"] = round(value(m[:TotalPerUnitProdOMCosts]) * (1 - p.owner_tax_pct), digits=0)
	r["gen_total_fuel_cost"] = round(value(m[:TotalGenFuelCharges]) * (1 - p.offtaker_tax_pct), digits=2)
	r["gen_year_one_fuel_cost"] = round(value(m[:TotalGenFuelCharges]) / p.pwf_e, digits=2)
	r["gen_year_one_variable_om_costs"] = round(value(GenPerUnitProdOMCosts) / (p.pwf_om * p.two_party_factor), digits=0)
	r["gen_year_one_fixed_om_costs"] = round(value(GenPerUnitSizeOMCosts) / (p.pwf_om * p.two_party_factor), digits=0)

	generatorToBatt = @expression(m, [ts in p.time_steps],
		sum(m[:dvProductionToStorage][b, t, ts] for b in p.storage.types, t in p.gentechs))
	r["generatorToBatt"] = round.(value.(generatorToBatt), digits=3)

	generatorToGrid = @expression(m, [ts in p.time_steps],
		sum(m[:dvWHLexport][t, ts] + m[:dvNEMexport][t, ts] for t in p.gentechs)
	)
	r["generatorToGrid"] = round.(value.(generatorToGrid), digits=3)

	generatorToLoad = @expression(m, [ts in p.time_steps],
		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.gentechs) -
			generatorToBatt[ts] - generatorToGrid[ts]
	)
	r["generatorToLoad"] = round.(value.(generatorToLoad), digits=3)

    GeneratorFuelUsed = @expression(m, sum(m[:dvFuelUsage][t, ts] for t in p.gentechs, ts in p.time_steps))
	r["fuel_used_gal"] = round(value(GeneratorFuelUsed), digits=2)

	Year1GenProd = @expression(m,
		p.hours_per_timestep * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts]
			for t in p.gentechs, ts in p.time_steps)
	)
	r["year_one_gen_energy_produced"] = round(value(Year1GenProd), digits=0)
	AverageGenProd = @expression(m,
		p.hours_per_timestep * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts] *
		p.levelization_factor[t]
			for t in p.gentechs, ts in p.time_steps)
	)
	r["average_yearly_gen_energy_produced"] = round(value(AverageGenProd), digits=0)
	nothing
end

function add_outage_results(m, p, r::Dict)
	# TODO with many outages the dispatch arrays are so large that it can take hours to create them
	# (eg. 8760 * 12 hour outages with PV, storage and diesel makes 7*12*8760 = 735,840 values)
	# For now the outage dispatch outputs are not created (commented out below). Perhaps make a new
	# function to optionally get the outage dispatch values so that we don't slow down returning the
	# other results.
	r["expected_outage_cost"] = value(m[:ExpectedOutageCost])
	r["max_outage_cost_per_outage_duration"] = value.(m[:dvMaxOutageCost]).data
	r["dvUnservedLoad"] = value.(m[:dvUnservedLoad]).data
	S = length(p.elecutil.scenarios)
	T = length(p.elecutil.outage_start_timesteps)
	unserved_load_per_outage = Array{Float64}(undef, S, T)
	for s in 1:S, t in 1:T
		unserved_load_per_outage[s, t] = sum(r["dvUnservedLoad"][s, t, ts] for 
											 ts in 1:p.elecutil.outage_durations[s]) 
	# need the ts in 1:p.elecutil.outage_durations[s] b/c dvUnservedLoad has unused values in third dimension
	end
	r["unserved_load_per_outage"] = round.(unserved_load_per_outage, digits=2)
	r["mg_storage_upgrade_cost"] = value(m[:dvMGStorageUpgradeCost])
	r["dvMGDischargeFromStorage"] = value.(m[:dvMGDischargeFromStorage]).data

	for t in p.techs
		r[t * "_upgraded"] = value(m[:binMGTechUsed][t])
	end
	r["storage_upgraded"] = value(m[:binMGStorageUsed])

	if !isempty(p.pvtechs)
		for t in p.pvtechs

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(r[t * "_upgraded"])
				r[string(t, "mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "mg_kw")] = 0
			end
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)

			if !isempty(p.storage.types)
				PVtoBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.elecutil.scenarios,
					tz in p.elecutil.outage_start_timesteps,
					ts in p.elecutil.outage_timesteps)
			else
				PVtoBatt = []
			end
			r[string("mg", t, "toBatt")] = round.(value.(PVtoBatt), digits=3)

			PVtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.elecutil.scenarios,
				tz in p.elecutil.outage_start_timesteps,
				ts in p.elecutil.outage_timesteps)
			r[string("mg", t, "toCurtail")] = round.(value.(PVtoCUR), digits=3)

			PVtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.elecutil.scenarios,
					tz in p.elecutil.outage_start_timesteps,
					ts in p.elecutil.outage_timesteps
			)
			r[string("mg", t, "toLoad")] = round.(value.(PVtoLoad), digits=3)
		end
	end

	if !isempty(p.gentechs)
		for t in p.gentechs

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(r[t * "_upgraded"])
				r[string(t, "_mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "mg_kw")] = 0
			end

			r[string("mg_", t, "_fuel_used")] = value.(m[:dvMGFuelUsed][t, :, :]).data
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)

			if !isempty(p.storage.types)
				GenToBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.elecutil.scenarios,
					tz in p.elecutil.outage_start_timesteps,
					ts in p.elecutil.outage_timesteps)
			else
				GenToBatt = []
			end
			r[string("mg", t, "toBatt")] = round.(value.(GenToBatt), digits=3)

			GENtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.elecutil.scenarios,
				tz in p.elecutil.outage_start_timesteps,
				ts in p.elecutil.outage_timesteps)
			r[string("mg", t, "toCurtail")] = round.(value.(GENtoCUR), digits=3)

			GENtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.elecutil.scenarios,
					tz in p.elecutil.outage_start_timesteps,
					ts in p.elecutil.outage_timesteps
			)
			r[string("mg", t, "toLoad")] = round.(value.(GENtoLoad), digits=3)
		end
	end
end