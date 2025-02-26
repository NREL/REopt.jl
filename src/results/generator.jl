# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`Generator` results keys:
- `size_kw` Optimal generator capacity
- `lifecycle_fixed_om_cost_after_tax` Lifecycle fixed operations and maintenance cost in present value, after tax
- `year_one_fixed_om_cost_before_tax` fixed operations and maintenance cost over the first year, before considering tax benefits
- `lifecycle_variable_om_cost_after_tax` Lifecycle variable operations and maintenance cost in present value, after tax
- `year_one_variable_om_cost_before_tax` variable operations and maintenance cost over the first year, before considering tax benefits
- `lifecycle_fuel_cost_after_tax` Lifecycle fuel cost in present value, after tax
- `year_one_fuel_cost_before_tax` Fuel cost over the first year, before considering tax benefits
- `annual_fuel_consumption_gal` Gallons of fuel used in each year
- `electric_to_storage_series_kw` Vector of power sent to battery in an average year
- `electric_to_grid_series_kw` Vector of power sent to grid in an average year
- `electric_to_load_series_kw` Vector of power sent to load in an average year
- `annual_energy_produced_kwh` Average annual energy produced over analysis period

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""
function add_generator_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	# Adds the `Generator` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
	# Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

	GenPerUnitSizeOMCosts = @expression(m, p.third_party_factor * p.pwf_om * sum(m[Symbol("dvSize"*_n)][t] * p.om_cost_per_kw[t] for t in p.techs.gen))

	GenPerUnitProdOMCosts = @expression(m, p.third_party_factor * p.pwf_om * p.hours_per_time_step *
		sum(m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.s.generator.om_cost_per_kwh
			for t in p.techs.gen, ts in p.time_steps)
	)
	r["size_kw"] = round(value(sum(m[Symbol("dvSize"*_n)][t] for t in p.techs.gen)), digits=2)
	r["lifecycle_fixed_om_cost_after_tax"] = round(value(GenPerUnitSizeOMCosts) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
	r["lifecycle_variable_om_cost_after_tax"] = round(value(m[Symbol("TotalPerUnitProdOMCosts"*_n)]) * (1 - p.s.financial.owner_tax_rate_fraction), digits=0)
	r["lifecycle_fuel_cost_after_tax"] = round(value(m[Symbol("TotalGenFuelCosts"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
	r["year_one_fuel_cost_before_tax"] = round(value(m[Symbol("TotalGenFuelCosts"*_n)]) / p.pwf_fuel["Generator"], digits=2)
	r["year_one_variable_om_cost_before_tax"] = round(value(GenPerUnitProdOMCosts) / (p.pwf_om * p.third_party_factor), digits=0)
	r["year_one_fixed_om_cost_before_tax"] = round(value(GenPerUnitSizeOMCosts) / (p.pwf_om * p.third_party_factor), digits=0)

	if !isempty(p.s.storage.types.elec)
	generatorToBatt = @expression(m, [ts in p.time_steps],
		sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec, t in p.techs.gen))
	else
		generatorToBatt = zeros(length(p.time_steps)) 
	end
	r["electric_to_storage_series_kw"] = round.(value.(generatorToBatt), digits=3)

	generatorToGrid = @expression(m, [ts in p.time_steps],
		sum(m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for t in p.techs.gen, u in p.export_bins_by_tech[t])
	)
	r["electric_to_grid_series_kw"] = round.(value.(generatorToGrid), digits=3)

	generatorToLoad = @expression(m, [ts in p.time_steps],
		sum(m[Symbol("dvRatedProduction"*_n)][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.techs.gen) -
			generatorToBatt[ts] - generatorToGrid[ts]
	)
	r["electric_to_load_series_kw"] = round.(value.(generatorToLoad), digits=3)

    GeneratorFuelUsed = @expression(m, sum(m[Symbol("dvFuelUsage"*_n)][t, ts] for t in p.techs.gen, ts in p.time_steps) / p.s.generator.fuel_higher_heating_value_kwh_per_gal)
	r["annual_fuel_consumption_gal"] = round(value(GeneratorFuelUsed), digits=2)

	AverageGenProd = @expression(m,
		p.hours_per_time_step * sum(m[Symbol("dvRatedProduction"*_n)][t,ts] * p.production_factor[t, ts] *
		p.levelization_factor[t]
			for t in p.techs.gen, ts in p.time_steps)
	)
	r["annual_energy_produced_kwh"] = round(value(AverageGenProd), digits=0)
    
	d["Generator"] = r
    nothing
end

"""
MPC `Generator` results keys:
- `variable_om_cost`
- `fuel_cost`
- `to_battery_series_kw`
- `to_grid_series_kw`
- `to_load_series_kw`
- `annual_fuel_consumption_gal`
- `energy_produced_kwh`
"""
function add_generator_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()

	r["variable_om_cost"] = round(value(m[:TotalPerUnitProdOMCosts]), digits=0)
	r["fuel_cost"] = round(value(m[:TotalGenFuelCosts]), digits=2)

    if p.s.storage.attr["ElectricStorage"].size_kw > 0
        generatorToBatt = @expression(m, [ts in p.time_steps],
            sum(m[:dvProductionToStorage][b, t, ts] for b in p.s.storage.types.elec, t in p.techs.gen))
        r["to_battery_series_kw"] = round.(value.(generatorToBatt), digits=3).data
    else
        generatorToBatt = zeros(length(p.time_steps))
    end

	generatorToGrid = @expression(m, [ts in p.time_steps],
		sum(m[:dvProductionToGrid][t, u, ts] for t in p.techs.gen, u in p.export_bins_by_tech[t])
	)
	r["to_grid_series_kw"] = round.(value.(generatorToGrid), digits=3).data

	generatorToLoad = @expression(m, [ts in p.time_steps],
		sum(m[:dvRatedProduction][t, ts] * p.production_factor[t, ts] * p.levelization_factor[t]
			for t in p.techs.gen) -
			generatorToBatt[ts] - generatorToGrid[ts]
	)
	r["to_load_series_kw"] = round.(value.(generatorToLoad), digits=3).data

    GeneratorFuelUsed = @expression(m, sum(m[:dvFuelUsage][t, ts] for t in p.techs.gen, ts in p.time_steps) / p.s.generator.fuel_higher_heating_value_kwh_per_gal)
	r["annual_fuel_consumption_gal"] = round(value(GeneratorFuelUsed), digits=2)

	Year1GenProd = @expression(m,
		p.hours_per_time_step * sum(m[:dvRatedProduction][t,ts] * p.production_factor[t, ts]
			for t in p.techs.gen, ts in p.time_steps)
	)
	r["energy_produced_kwh"] = round(value(Year1GenProd), digits=0)
    
	d["Generator"] = r
    nothing
end
