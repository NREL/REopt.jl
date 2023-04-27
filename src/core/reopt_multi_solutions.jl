"""
    run_reopt_multi_solutions(fp::String, size_scale::Vector{Float64}, ms::AbstractVector{T})  where T <: JuMP.AbstractModel

Run REopt to get optimal tech sizes, and then run REopt multiple times with scaling factor size_scale applied to 
the optimal sizes to look at sensitivity of tech size on key results parameters

fp is the inputs .json file path
size_scale is the vector of scaling factors to apply to each optimal tech size
ms is a vector of identical JuMP model objects and the length has to be larger than the max possible REopt runs

"""
function run_reopt_multi_solutions(fp::String, size_scale::Vector{Float64}, ms::AbstractVector{T}) where T <: JuMP.AbstractModel
    # Run REopt the first time for optimal tech sizes
    n = 1  # Indexing into the ms vector of JuMP models
    input_data = JSON.parsefile(fp)
    p = REoptInputs(input_data)
    results = run_reopt(ms[n], p)
    n += 1

    # Check results to see which techs are sized, to inform number of solutions
    techs_possible = ["PV", "ElectricStorage", "Generator", "CHP"]
    techs_considered = intersect(techs_possible, keys(input_data))
    techs_sized = intersect(techs_possible, keys(results))
    techs_to_zero = setdiff(techs_considered, techs_sized)

    # TODO if length(techs_sized) == 0, no need to run BAU or any other cases, so skip!
    # Only need to run BAU once, and then run "combine_results()" N times to get Financial results for all
    bau_inputs = REopt.BAUInputs(p)
    bau_results = run_reopt(ms[n], bau_inputs)
    n += 1

    # Combine results for BAU-Opt to get e.g. NPV
    results_dict = REopt.combine_results(p, bau_results, results, bau_inputs.s)
    results_dict["Financial"] = merge(results_dict["Financial"], REopt.proforma_results(p, results_dict))

    # Now create number of solutions based on the # of techs sized in optimal case
    # TODO?? need to include where both/N techs are scaled together and in opposite directions
    results_all = Dict("optimal" => results_dict)
    results_summary = Dict("optimal" => get_multi_solutions_results_summary(results_dict, p, ms[1], techs_sized))
    for i in eachindex(size_scale)
        for tech in techs_sized
            # Copy input_data so all techs start at optimal size (size_scale = 1.0)
            # Remove techs which were considered but not sized (size=0) in optimal case
            input_data_s = deepcopy(input_data)
            for t in techs_to_zero
                delete!(input_data_s, t)
            end
            # Force size based on size_scale factor
            input_data_s[tech]["min_kw"] = results_all["optimal"][tech]["size_kw"] * size_scale[i]
            input_data_s[tech]["max_kw"] = results_all["optimal"][tech]["size_kw"] * size_scale[i]
            if tech == "ElectricStorage"
                input_data_s[tech]["min_kwh"] = results_all["optimal"][tech]["size_kwh"] * size_scale[i]
                input_data_s[tech]["max_kwh"] = results_all["optimal"][tech]["size_kwh"] * size_scale[i]
            end
            
            # Use modified inputs to run_reopt and get results
            local p = REoptInputs(input_data_s)
            local results = run_reopt(ms[n], input_data_s)
            
            # Combine with BAU to get e.g. NPV
            local results_dict = REopt.combine_results(p, bau_results, results, bau_inputs.s)
            results_dict["Financial"] = merge(results_dict["Financial"], REopt.proforma_results(p, results_dict))
            results_all[tech*"_size_scale_"*string(size_scale[i])] = results_dict
            
            # Build results summary, a select number of outputs for Eaton
            results_summary[tech*"_size_scale_"*string(size_scale[i])] = get_multi_solutions_results_summary(results_dict, p, ms[n], techs_sized)
            n += 1
        end
    end
    return results_all, results_summary
end

"""
    get_multi_solutions_results_summary(results::Dict, p::REoptInputs, m::JuMP.AbstractModel, techs_sized::Vector{String})

Get the results summary dictionary which is a selected number of outputs for Financial, Emissions, and 
the relevant techs

"""
function get_multi_solutions_results_summary(results::Dict, p::REoptInputs, m::JuMP.AbstractModel, techs_sized::Vector{String})
    # results_summary always has Financial and emissions, and then add techs as needed
    results_summary = Dict(
        "Financial" =>
            Dict("Net Present Value" => results["Financial"]["npv"],
                "Simple payback period" => results["Financial"]["simple_payback_years"],
                "Net capital cost" => results["Financial"]["lifecycle_capital_costs"],
                "Internal Rate of Return %" => results["Financial"]["internal_rate_of_return"] * 100.0),
        "emissions" => 
            Dict("Site life cycle CO2 tonnes" => results["Site"]["lifecycle_emissions_tonnes_CO2"],
                "Site life cycle NOx tonnes" => results["Site"]["lifecycle_emissions_tonnes_NOx"],
                "Site life cycle SO2 tonnes" => results["Site"]["lifecycle_emissions_tonnes_SO2"],
                "Site life cycle PM25 tonnes" => results["Site"]["lifecycle_emissions_tonnes_PM25"])
    )

    # Add techs if they have been sized in the optimal case
    for key in techs_sized
        if key == "PV"
            # Note, capital cost is "net" of incentives, and Maintenance cost is year-one
            results_summary["PV"] = 
                Dict("Rated capacity" => results[key]["size_kw"],
                    "Average annual energy produced" => results[key]["year_one_energy_produced_kwh"],
                    "Capital cost" => p.cap_cost_slope[key] * results[key]["size_kw"],
                    "Annual maintenance cost" => p.s.pvs[1].om_cost_per_kw * results[key]["size_kw"])
        elseif key == "ElectricStorage"
            # Note, capital cost is "net" of incentives, and Maintenance cost is year-one
            # Estimate the installed upfront cost versus the replacement cost by scaling inputs
            # TODO this has become complicated and might be easier to just leverage effective_cost REopt function
            net_installed_plus_replace_cost = value(m[Symbol("TotalStorageCapCosts")])
            total_input_cost_per_kw = p.s.storage.attr[key].installed_cost_per_kw + p.s.storage.attr[key].replace_cost_per_kw
            total_input_cost_per_kwh = p.s.storage.attr[key].installed_cost_per_kwh + p.s.storage.attr[key].replace_cost_per_kwh
            replacement_fraction_per_kw = p.s.storage.attr[key].replace_cost_per_kw / total_input_cost_per_kw
            replacement_fraction_per_kwh = p.s.storage.attr[key].replace_cost_per_kwh / total_input_cost_per_kwh
            replacement_cost_fraction = (replacement_fraction_per_kw * results[key]["size_kw"] + 
                                        replacement_fraction_per_kwh * results[key]["size_kwh"]) /
                                        (results[key]["size_kw"] + results[key]["size_kwh"])
            net_replacement_cost = net_installed_plus_replace_cost * replacement_cost_fraction
            net_installed_cost = net_installed_plus_replace_cost - net_replacement_cost
            results_summary["Storage"] = 
                Dict("Rated energy capacity" => results[key]["size_kwh"],
                    "Rated inverter capacity" => results[key]["size_kw"],
                    "Capital cost" => net_installed_cost,
                    "Total replacement cost" => net_replacement_cost)
        elseif key == "Generator"
            results_summary["Generator"] = 
                Dict("Rated capacity" => results[key]["size_kw"],
                    "Capital cost" => p.cap_cost_slope[key] * results[key]["size_kw"],
                    "Annual maintenance cost" => p.s.generator.om_cost_per_kw * results[key]["size_kw"],
                    "Life cycle fuel cost after tax" => results[key]["lifecycle_fuel_cost_after_tax"],
                    "Annual fuel used gallons" => results[key]["annual_fuel_consumption_gal"],
                    "Annual energy produced" => results[key]["annual_energy_produced_kwh"])
        elseif key == "CHP"
            cap_cost = p.third_party_factor * (
                    sum(p.cap_cost_slope[key][s] * value(m[Symbol("dvSegmentSystemSize"*key)][s]) + 
                    p.seg_yint[key][s] * value(m[Symbol("binSegment"*key)][s]) for s in 1:p.n_segs_by_tech[key]))
            var_om_cost = (value(m[Symbol("TotalCHPPerUnitProdOMCosts")]) + value(m[Symbol("TotalHourlyCHPOMCosts")])) / 
                            p.third_party_factor * p.pwf_om
            fixed_om_cost = p.s.chp.om_cost_per_kw * results[key]["size_kw"]
            results_summary["Fuel Cell"] = 
                Dict("Rated capacity" => results[key]["size_kw"],
                    "Capital cost" => cap_cost,
                    "Annual maintenance cost" => var_om_cost + fixed_om_cost,
                    "Annual energy produced" => results[key]["annual_electric_production_kwh"],
                    "Life cycle fuel cost after tax" => results[key]["lifecycle_fuel_cost_after_tax"],
                    "Annual fuel used MMBtu" => results[key]["annual_fuel_consumption_mmbtu"],
                    "Life cycle standby cost after tax" => results[key]["lifecycle_standby_cost_after_tax"])
        end
    end
    return results_summary
end