# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`Financial` results keys:
- `lcc` Optimal lifecycle cost
- `lifecycle_generation_tech_capital_costs` LCC component. Net capital costs for all generation technologies, in present value, including replacement costs and incentives. This value does not include offgrid_other_capital_costs.
- `lifecycle_storage_capital_costs` LCC component. Net capital costs for all storage technologies, in present value, including replacement costs and incentives. This value does not include offgrid_other_capital_costs.
- `lifecycle_om_costs_after_tax` LCC component. Present value of all O&M costs, after tax. (does not include fuel costs)
- `lifecycle_fuel_costs_after_tax` LCC component. Present value of all fuel costs over the analysis period, after tax.
- `lifecycle_chp_standby_cost_after_tax` LCC component. Present value of all CHP standby charges, after tax.
- `lifecycle_elecbill_after_tax` LCC component. Present value of all electric utility charges, after tax. 
- `lifecycle_production_incentive_after_tax` LCC component. Present value of all production-based incentives, after tax.
- `lifecycle_offgrid_other_annual_costs_after_tax` LCC component. Present value of offgrid_other_annual_costs over the analysis period, after tax. 
- `lifecycle_offgrid_other_capital_costs` LCC component. Equal to offgrid_other_capital_costs with straight line depreciation applied over analysis period. The depreciation expense is assumed to reduce the owner's taxable income.
- `lifecycle_outage_cost` LCC component. Expected outage cost. 
- `lifecycle_MG_upgrade_and_fuel_cost` LCC component. Cost to upgrade generation and storage technologies to be included in microgrid, plus expected microgrid fuel costs, assuming outages occur in first year with specified probabilities.
- `lifecycle_om_costs_before_tax` Present value of all O&M costs, before tax.
- `year_one_om_costs_before_tax` Year one O&M costs, before tax.
- `year_one_om_costs_after_tax` Year one O&M costs, after tax.
- `lifecycle_capital_costs_plus_om_after_tax` Capital cost for all technologies plus present value of operations and maintenance over anlaysis period. This value does not include offgrid_other_capital_costs.
- `lifecycle_capital_costs` Net capital costs for all technologies, in present value, including replacement costs and incentives. This value does not include offgrid_other_capital_costs.
- `initial_capital_costs` Up-front capital costs for all technologies, in present value, excluding replacement costs and incentives. This value does not include offgrid_other_capital_costs.
- `initial_capital_costs_after_incentives` Up-front capital costs for all technologies, in present value, excluding replacement costs, and accounting for incentives. This value does not include offgrid_other_capital_costs.
- `replacements_future_cost_after_tax` Future cost of replacing storage and/or generator systems, after tax.
- `replacements_present_cost_after_tax` Present value cost of replacing storage and/or generator systems, after tax.
- `om_and_replacement_present_cost_after_tax` Present value of all O&M and replacement costs, after tax.
- `developer_om_and_replacement_present_cost_after_tax` Present value of all O&M and replacement costs incurred by developer, after tax.
- `offgrid_microgrid_lcoe_dollars_per_kwh` Levelized cost of electricity for modeled off-grid system.
- `lifecycle_emissions_cost_climate` LCC component if Settings input include_climate_in_objective is true. Present value of CO2 emissions cost over the analysis period.
- `lifecycle_emissions_cost_health` LCC component if Settings input include_health_in_objective is true. Present value of NOx, SO2, and PM2.5 emissions cost over the analysis period.

calculated in combine_results function if BAU scenario is run:
- `breakeven_cost_of_emissions_reduction_per_tonne_CO2`

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 

"""
function add_financial_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Float64}()
    if !(Symbol("TotalProductionIncentive"*_n) in keys(m.obj_dict)) # not currently included in multi-node modeling b/c these constraints require binary vars.
        m[Symbol("TotalProductionIncentive"*_n)] = 0.0
    end
    if !(Symbol("TotalPerUnitHourOMCosts"*_n) in keys(m.obj_dict)) # CHP not currently included in multi-node modeling  
        m[Symbol("TotalPerUnitHourOMCosts"*_n)] = 0.0
    end
    if !(Symbol("GHPOMCosts"*_n) in keys(m.obj_dict)) # CHP not currently included in multi-node modeling  
        m[Symbol("GHPOMCosts"*_n)] = 0.0
    end
    if !(Symbol("GHPCapCosts"*_n) in keys(m.obj_dict)) # GHP not currently included in multi-node modeling  
        m[Symbol("GHPCapCosts"*_n)] = 0.0
    end

    r["lcc"] = value(m[Symbol("Costs"*_n)]) + 0.0001 * value(m[Symbol("MinChargeAdder"*_n)])

    r["lifecycle_om_costs_before_tax"] = value(m[Symbol("TotalPerUnitSizeOMCosts"*_n)] + 
                                           m[Symbol("TotalPerUnitProdOMCosts"*_n)] + m[Symbol("TotalPerUnitHourOMCosts"*_n)] + m[Symbol("GHPOMCosts"*_n)])
    
    ## LCC breakdown: ##
    r["lifecycle_generation_tech_capital_costs"] = value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("GHPCapCosts"*_n)]) # Tech capital costs (including replacements)
    r["lifecycle_storage_capital_costs"] = value(m[Symbol("TotalStorageCapCosts"*_n)]) # Storage capital costs (including replacements)
    r["lifecycle_om_costs_after_tax"] = r["lifecycle_om_costs_before_tax"] * (1 - p.s.financial.owner_tax_rate_fraction)  # Fixed & Variable O&M 
    if !isempty(p.techs.fuel_burning)
        r["lifecycle_fuel_costs_after_tax"] = value(m[:TotalFuelCosts]) * (1 - p.s.financial.offtaker_tax_rate_fraction)
    else
        r["lifecycle_fuel_costs_after_tax"] = 0.0
    end
    if !(Symbol("TotalCHPStandbyCharges"*_n) in keys(m.obj_dict)) # CHP standby charges not currently included in multi-node modeling
        m[Symbol("TotalCHPStandbyCharges"*_n)] = 0.0
    end
    r["lifecycle_chp_standby_cost_after_tax"] = value(m[Symbol("TotalCHPStandbyCharges"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction) # CHP standby
    r["lifecycle_elecbill_after_tax"] = value(m[Symbol("TotalElecBill"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction)  # Total utility bill 
    r["lifecycle_production_incentive_after_tax"] = value(m[Symbol("TotalProductionIncentive"*_n)])  * (1 - p.s.financial.owner_tax_rate_fraction)  # Production incentives
    if p.s.settings.off_grid_flag # Offgrid other annual and capital costs
        r["lifecycle_offgrid_other_annual_costs_after_tax"] = p.s.financial.offgrid_other_annual_costs * p.pwf_om * (1 - p.s.financial.owner_tax_rate_fraction)
        r["lifecycle_offgrid_other_capital_costs"] = m[:OffgridOtherCapexAfterDepr]
    else
        r["lifecycle_offgrid_other_annual_costs_after_tax"] = 0.0
        r["lifecycle_offgrid_other_capital_costs"] = 0.0
    end
    if !isempty(p.s.electric_utility.outage_durations)  # Outage and MG upgrade & fuel costs
        r["lifecycle_outage_cost"] = value(m[:ExpectedOutageCost])
        r["lifecycle_MG_upgrade_and_fuel_cost"] = value(m[:mgTotalTechUpgradeCost] + m[:dvMGStorageUpgradeCost] + m[:ExpectedMGFuelCost]) 
	else
        r["lifecycle_outage_cost"] = 0.0
        r["lifecycle_MG_upgrade_and_fuel_cost"] = 0.0
    end
    ## End LCC breakdown ## 

    r["year_one_om_costs_before_tax"] = r["lifecycle_om_costs_before_tax"] / (p.pwf_om * p.third_party_factor)
    r["year_one_om_costs_after_tax"] = r["lifecycle_om_costs_after_tax"] / (p.pwf_om * p.third_party_factor)

    r["lifecycle_capital_costs_plus_om_after_tax"] = value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)] + m[Symbol("GHPCapCosts"*_n)]) + r["lifecycle_om_costs_after_tax"]
    
    r["lifecycle_capital_costs"] = value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)] + m[Symbol("GHPCapCosts"*_n)])
    
    r["initial_capital_costs"] = initial_capex(m, p; _n=_n)
    future_replacement_cost, present_replacement_cost = replacement_costs_future_and_present(m, p; _n=_n)
    r["initial_capital_costs_after_incentives"] = r["lifecycle_capital_costs"] / p.third_party_factor - present_replacement_cost

    r["replacements_future_cost_after_tax"] = future_replacement_cost 
    r["replacements_present_cost_after_tax"] = present_replacement_cost 
    r["om_and_replacement_present_cost_after_tax"] = present_replacement_cost + r["lifecycle_om_costs_after_tax"]
    r["developer_om_and_replacement_present_cost_after_tax"] = r["om_and_replacement_present_cost_after_tax"] / 
        p.third_party_factor

    if p.s.settings.off_grid_flag        
        if p.third_party_factor == 1 # ==1 with Direct ownership (when third_party_ownership is False)
            pwf = p.pwf_offtaker
        else
            pwf = p.pwf_owner
        end
        LoadMet = @expression(m, sum(p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts] for ts in p.time_steps_without_grid ))
        r["offgrid_microgrid_lcoe_dollars_per_kwh"] = round(r["lcc"] / pwf / value(LoadMet), digits=4)
    end

    if _n==""
        r["lifecycle_emissions_cost_climate"] = round(value(m[:Lifecycle_Emissions_Cost_CO2]), digits=2)
        r["lifecycle_emissions_cost_health"] = round(value(m[:Lifecycle_Emissions_Cost_Health]), digits=2)
    end

    d["Financial"] = Dict{String,Float64}(k => round(v, digits=4) for (k,v) in r)
    nothing
end


"""
    initial_capex(m::JuMP.AbstractModel, p::REoptInputs; _n="")

Calculate and return the up-front capital costs for all technologies, in present value, excluding replacement costs and 
incentives.
"""
function initial_capex(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    initial_capex = 0

    if !isempty(p.techs.gen) && isempty(_n)  # generators not included in multinode model
        initial_capex += p.s.generator.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Generator"]
    end

    if !isempty(p.techs.pv)
        for pv in p.s.pvs
            initial_capex += pv.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])[pv.name]
        end
    end

    for b in p.s.storage.types.elec
        if p.s.storage.attr[b].max_kw > 0
            initial_capex += p.s.storage.attr[b].installed_cost_per_kw * value.(m[Symbol("dvStoragePower"*_n)])[b] + 
                p.s.storage.attr[b].installed_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
        end
    end

    for b in p.s.storage.types.thermal
        if p.s.storage.attr[b].max_kw > 0
            initial_capex += p.s.storage.attr[b].installed_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
        end
    end

    if "Wind" in p.techs.all
        initial_capex += p.s.wind.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Wind"]
    end

    if "CHP" in p.techs.all
        chp_size_kw = value.(m[Symbol("dvPurchaseSize"*_n)])["CHP"]
        initial_capex += get_chp_initial_capex(p, chp_size_kw)
    end

    if "SteamTurbine" in p.techs.all
        initial_capex += p.s.steam_turbine.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["SteamTurbine"]
    end

    if "Boiler" in p.techs.all
        initial_capex += p.s.boiler.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Boiler"]
    end

    if "AbsorptionChiller" in p.techs.all
        initial_capex += p.s.absorption_chiller.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["AbsorptionChiller"]
    end

    if !isempty(p.s.ghp_option_list)

        for option in enumerate(p.s.ghp_option_list)

            if option[2].heat_pump_configuration == "WSHP"
                initial_capex += option[2].installed_cost_per_kw[2]*option[2].heatpump_capacity_ton*value(m[Symbol("binGHP"*_n)][option[1]])
            elseif option[2].heat_pump_configuration == "WWHP"
                initial_capex += (option[2].wwhp_heating_pump_installed_cost_curve[2]*option[2].wwhp_heating_pump_capacity_ton + option[2].wwhp_cooling_pump_installed_cost_curve[2]*option[2].wwhp_cooling_pump_capacity_ton)*value(m[Symbol("binGHP"*_n)][option[1]])
            else
                @warn "Unknown heat pump configuration provided, excluding GHP costs from initial capital costs."
            end
        end
    end

    if "ASHPSpaceHeater" in p.techs.all
        initial_capex += p.s.ashp.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["ASHPSpaceHeater"]
    end

    if "ASHPWaterHeater" in p.techs.all
        initial_capex += p.s.ashp_wh.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["ASHPWaterHeater"]
    end    

    return initial_capex
end


"""
    replacement_costs_future_and_present(m::JuMP.AbstractModel, p::REoptInputs; _n="")

Replacement costs for storage and generator are not considered if the replacement year is >= the analysis period.
NOTE the owner_discount_rate_fraction and owner_tax_rate_fraction are set to the offtaker_discount_rate_fraction and offtaker_tax_rate_fraction 
 respectively when third_party_ownership is False.
NOTE these replacement costs include the tax benefit available to commercial entities (i.e., assume replacement costs are tax deductible)

returns two values: the future and present costs of replacing all storage and generator systems
"""
function replacement_costs_future_and_present(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    future_cost = 0
    present_cost = 0

    for b in p.s.storage.types.all # Storage replacement

        if !(:inverter_replacement_year in fieldnames(typeof(p.s.storage.attr[b])))
            continue
        end

        if p.s.storage.attr[b].inverter_replacement_year >= p.s.financial.analysis_years
            future_cost_inverter = 0
        else
            future_cost_inverter = p.s.storage.attr[b].replace_cost_per_kw * value.(m[Symbol("dvStoragePower"*_n)])[b]
        end
        if p.s.storage.attr[b].battery_replacement_year >= p.s.financial.analysis_years
            future_cost_storage = 0
        else
            future_cost_storage = p.s.storage.attr[b].replace_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
        end
        future_cost += future_cost_inverter + future_cost_storage

        present_cost += future_cost_inverter * (1 - p.s.financial.owner_tax_rate_fraction) / 
            ((1 + p.s.financial.owner_discount_rate_fraction)^p.s.storage.attr[b].inverter_replacement_year)
        present_cost += future_cost_storage * (1 - p.s.financial.owner_tax_rate_fraction) / 
            ((1 + p.s.financial.owner_discount_rate_fraction)^p.s.storage.attr[b].battery_replacement_year)
    end

    if !isempty(p.techs.gen) # Generator replacement 
        if p.s.generator.replacement_year >= p.s.financial.analysis_years 
            future_cost_generator = 0.0
        else 
            future_cost_generator = p.s.generator.replace_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Generator"]
        end
        future_cost += future_cost_generator
        present_cost += future_cost_generator * (1 - p.s.financial.owner_tax_rate_fraction) / 
            ((1 + p.s.financial.owner_discount_rate_fraction)^p.s.generator.replacement_year)
    end

    return future_cost, present_cost
end


"""
    calculate_lcoe(p::REoptInputs, tech_results::Dict, tech::AbstractTech)

The Levelized Cost of Energy (LCOE) is calculated as annualized costs (capital and O+M translated to current value) 
divided by annual energy output. This tech-specific LCOE is distinct from the off-grid microgrid LCOE.
"""
function calculate_lcoe(p::REoptInputs, tech_results::Dict, tech::AbstractTech)
    existing_kw = :existing_kw in fieldnames(typeof(tech)) ? tech.existing_kw : 0.0
    new_kw = get(tech_results, "size_kw", 0) - existing_kw # new capacity
    if new_kw == 0
        return 0.0
    end

    years = p.s.financial.analysis_years # length of financial life
    # TODO is most of this calculated in proforma metrics?
    if p.s.financial.third_party_ownership
        discount_rate_fraction = p.s.financial.owner_discount_rate_fraction
        federal_tax_rate_fraction = p.s.financial.owner_tax_rate_fraction
    else
        discount_rate_fraction = p.s.financial.offtaker_discount_rate_fraction
        federal_tax_rate_fraction = p.s.financial.offtaker_tax_rate_fraction
    end

    capital_costs = new_kw * tech.installed_cost_per_kw # pre-incentive capital costs

    annual_om = new_kw * tech.om_cost_per_kw 

    om_series = [annual_om * (1+p.s.financial.om_cost_escalation_rate_fraction)^yr for yr in 1:years]
    npv_om = sum([om * (1.0/(1.0+discount_rate_fraction))^yr for (yr, om) in enumerate(om_series)]) # NPV of O&M charges escalated over financial life

    #Incentives as calculated in the spreadsheet, note utility incentives are applied before state incentives
    utility_ibi = min(capital_costs * tech.utility_ibi_fraction, tech.utility_ibi_max)
    utility_cbi = min(new_kw * tech.utility_rebate_per_kw, tech.utility_rebate_max)
    state_ibi = min((capital_costs - utility_ibi - utility_cbi) * tech.state_ibi_fraction, tech.state_ibi_max)
    state_cbi = min(new_kw * tech.state_rebate_per_kw, tech.state_rebate_max)
    federal_cbi = new_kw * tech.federal_rebate_per_kw
    ibi = utility_ibi + state_ibi  #total investment-based incentives
    cbi = utility_cbi + federal_cbi + state_cbi #total capacity-based incentives

    #calculate energy in the BAU case, used twice later on
    existing_energy_bau = get(tech_results, "year_one_energy_produced_kwh_bau", 0)

    #calculate the value of the production-based incentive stream
    npv_pbi = 0
    year_one_energy_produced = "year_one_energy_produced_kwh" in keys(tech_results) ? tech_results["year_one_energy_produced_kwh"] : tech_results["annual_energy_produced_kwh"]
    degradation_fraction = :degradation_fraction in fieldnames(typeof(tech)) ? tech.degradation_fraction : 0.0
    if tech.production_incentive_max_benefit > 0
        for yr in 1:years
            if yr < tech.production_incentive_years
                degradation_fraction = (1- degradation_fraction)^yr
                base_pbi = minimum([tech.production_incentive_per_kwh * 
                    (year_one_energy_produced - existing_energy_bau) * degradation_fraction,  
                    tech.production_incentive_max_benefit * degradation_fraction 
                ])
                npv_pbi += base_pbi * (1.0/(1.0+discount_rate_fraction))^(yr+1)
            end
        end
    end

    npv_federal_itc = 0
    federal_itc_basis = capital_costs - state_ibi - utility_ibi - state_cbi - utility_cbi - federal_cbi
    federal_itc_amount = tech.federal_itc_fraction * federal_itc_basis
    npv_federal_itc = federal_itc_amount * (1.0/(1.0+discount_rate_fraction))

    if tech.macrs_option_years in [5 ,7]
        depreciation_schedule = get_depreciation_schedule(p, tech, federal_itc_basis)
    else
        depreciation_schedule = zeros(years)
    end

    tax_deductions = (om_series + depreciation_schedule) * federal_tax_rate_fraction
    npv_tax_deductions = sum([i* (1.0/(1.0+discount_rate_fraction))^yr for (yr,i) in enumerate(tax_deductions)])

    #we only care about the energy produced by new capacity in LCOE calcs
    annual_energy = year_one_energy_produced - existing_energy_bau
    npv_annual_energy = sum([annual_energy * (1.0/(1.0+discount_rate_fraction))^yr * 
        (1- degradation_fraction)^(yr-1) for yr in 1:years])

    #LCOE is calculated as annualized costs divided by annualized energy
    lcoe = (capital_costs + npv_om - npv_pbi - cbi - ibi - npv_federal_itc - npv_tax_deductions ) / npv_annual_energy

    return round(lcoe, digits=4)
end

"""
    get_depreciation_schedule(p::REoptInputs, tech::AbstractTech, federal_itc_basis::Float64=0.0)

Get the depreciation schedule for MACRS. First check if tech.macrs_option_years in [5 ,7], then call function to return depreciation schedule
Used in results/financial.jl and results/proformal.jl multiple times
"""
function get_depreciation_schedule(p::REoptInputs, tech::Union{AbstractTech,AbstractStorage}, federal_itc_basis::Float64=0.0)
    schedule = []
    if tech.macrs_option_years == 5
        schedule = p.s.financial.macrs_five_year
    elseif tech.macrs_option_years == 7
        schedule = p.s.financial.macrs_seven_year
    end

    federal_itc_fraction = 0.0
    try 
        federal_itc_fraction = tech.federal_itc_fraction
    catch
        @warn "Did not find $(tech).federal_itc_fraction so using 0.0 in calculation of depreciation_schedule."
    end
    
    macrs_bonus_basis = federal_itc_basis - federal_itc_basis * federal_itc_fraction * tech.macrs_itc_reduction
    macrs_basis = macrs_bonus_basis * (1 - tech.macrs_bonus_fraction)

    depreciation_schedule = zeros(p.s.financial.analysis_years)
    for (i, r) in enumerate(schedule)
        if i < length(depreciation_schedule)
            depreciation_schedule[i] = macrs_basis * r
        end
    end
    depreciation_schedule[1] += (tech.macrs_bonus_fraction * macrs_bonus_basis)

    return depreciation_schedule
end


""" 
    get_chp_initial_capex(p::REoptInputs, size_kw::Float64)

CHP has a cost-curve input option, so calculating the initial CapEx requires more logic than typical tech CapEx calcs
"""
function get_chp_initial_capex(p::REoptInputs, size_kw::Float64)
    # CHP.installed_cost_per_kw is now a list with potentially > 1 elements
    cost_list = p.s.chp.installed_cost_per_kw
    size_list = p.s.chp.tech_sizes_for_cost_curve
    chp_size = size_kw
    initial_capex = 0.0
    if typeof(cost_list) == Vector{Float64}
        if chp_size <= size_list[1]
            initial_capex = chp_size * cost_list[1]  # Currently not handling non-zero cost ($) for 0 kW size input
        elseif chp_size > size_list[end]
            initial_capex = chp_size * cost_list[end]
        else
            for s in 2:length(size_list)
                if (chp_size > size_list[s-1]) && (chp_size <= size_list[s])
                    slope = (cost_list[s] * size_list[s] - cost_list[s-1] * size_list[s-1]) /
                            (size_list[s] - size_list[s-1])
                    initial_capex = cost_list[s-1] * size_list[s-1] + (chp_size - size_list[s-1]) * slope
                end
            end
        end
    else
        initial_capex = cost_list * chp_size
    #Add supplementary firing capital cost
    # chp_supp_firing_size = self.nested_outputs["Scenario"]["Site"][tech].get("size_supplementary_firing_kw")
    # chp_supp_firing_cost = self.inputs[tech].get("supplementary_firing_capital_cost_per_kw") or 0
    # initial_capex += chp_supp_firing_size * chp_supp_firing_cost
    end

    return initial_capex
end