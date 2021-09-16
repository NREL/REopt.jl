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
    add_financial_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the Financial results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

Financial results:
- `lcc` Optimal lifecycle cost
- `net_capital_costs_plus_om` Capital cost for all technologies plus present value of operations and maintenance over anlaysis period
- `net_capital_costs` Net capital costs for all technologies, in present value, including replacement costs and incentives.
"""
function add_financial_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["lcc"] = value(m[Symbol("Costs"*_n)]) + 0.0001 * value(m[Symbol("MinChargeAdder"*_n)])
    r["total_om_costs_before_tax"] = value(m[Symbol("TotalPerUnitSizeOMCosts"*_n)] + 
                                           m[Symbol("TotalPerUnitProdOMCosts"*_n)])
    r["year_one_om_costs_before_tax"] = r["total_om_costs_before_tax"] / (p.pwf_om * p.third_party_factor)
    r["total_om_costs_after_tax"] = r["total_om_costs_before_tax"] * (1 - p.s.financial.owner_tax_pct)
    r["year_one_om_costs_after_tax"] = r["total_om_costs_after_tax"] / (p.pwf_om * p.third_party_factor)

    r["net_capital_costs_plus_om"] = value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)]) +
        r["total_om_costs_after_tax"]
    r["net_capital_costs"] = value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)])
    r["initial_capital_costs"] = initial_capex(m, p; _n=_n)
    r["initial_capital_costs_after_incentives"] = initial_capex_after_incentives(m, p, r["net_capital_costs"]; _n=_n)

    future_replacement_cost, present_replacement_cost = replacement_costs_future_and_present(m, p; _n=_n)
    r["replacement_costs"] = future_replacement_cost
    r["om_and_replacement_present_cost_after_tax"] = present_replacement_cost + r["total_om_costs_after_tax"]
    r["developer_om_and_replacement_present_cost_after_tax"] = r["om_and_replacement_present_cost_after_tax"] / 
        p.third_party_factor

    d["Financial"] = Dict(k => round(v, digits=2) for (k,v) in r)
    nothing
end


"""
    initial_capex(m::JuMP.AbstractModel, p::REoptInputs; _n="")

Calculate and return the up-front capital costs for all technologies, in present value, excluding replacement costs and 
incentives.
"""
function initial_capex(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    initial_capex = 0

    if !isempty(p.gentechs) && isempty(_n)  # generators not included in multinode model
        initial_capex += p.s.generator.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Generator"]
    end

    if !isempty(p.pvtechs)
        for pv in p.s.pvs
            initial_capex += pv.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])[pv.name]
        end
    end

    for b in p.s.storage.types
        if p.s.storage.max_kw[b] > 0
            initial_capex += p.s.storage.raw_inputs[b].installed_cost_per_kw * value.(m[Symbol("dvStoragePower"*_n)])[b] + 
                p.s.storage.raw_inputs[b].installed_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
        end
    end

    if "Wind" in p.techs
        initial_capex += p.s.wind.installed_cost_per_kw * value.(m[Symbol("dvPurchaseSize"*_n)])["Wind"]
    end

    # TODO thermal tech costs

    return initial_capex
end


"""
    initial_capex_after_incentives(m::JuMP.AbstractModel, p::REoptInputs, net_capital_costs::Float64; _n="")

The net_capital_costs output is the initial capex after incentives, except it includes the battery
replacement cost in present value. So we calculate the initial_capex_after_incentives as net_capital_costs
minus the battery replacement cost in present value.
Note that the owner_discount_pct and owner_tax_pct are set to the offtaker_discount_pct and offtaker_tax_pct
respectively when third_party_ownership is False.
"""
function initial_capex_after_incentives(m::JuMP.AbstractModel, p::REoptInputs, net_capital_costs::Float64; _n="")
    initial_capex_after_incentives = net_capital_costs / p.third_party_factor

    for b in p.s.storage.types

        if !(:inverter_replacement_year in fieldnames(typeof(p.s.storage.raw_inputs[b])))
            continue
        end

        pwf_inverter = 1 / ((1 + p.s.financial.owner_discount_pct)^p.s.storage.raw_inputs[b].inverter_replacement_year)

        pwf_storage  = 1 / ((1 + p.s.financial.owner_discount_pct)^p.s.storage.raw_inputs[b].battery_replacement_year)

        inverter_future_cost = p.s.storage.raw_inputs[b].replace_cost_per_kw * value.(m[Symbol("dvStoragePower"*_n)])[b]

        storage_future_cost = p.s.storage.raw_inputs[b].replace_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]

        # NOTE these initial costs include the tax benefit available to commercial entities
        initial_capex_after_incentives -= inverter_future_cost * pwf_inverter * (1 - p.s.financial.owner_tax_pct)
        initial_capex_after_incentives -= storage_future_cost  * pwf_storage  * (1 - p.s.financial.owner_tax_pct)
    end

    return initial_capex_after_incentives
end


"""
    replacement_costs_future_and_present(m::JuMP.AbstractModel, p::REoptInputs; _n="")

returns two values: the future and present costs of replacing all storage systems
"""
function replacement_costs_future_and_present(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    future_cost = 0
    present_cost = 0
    for b in p.s.storage.types

        if !(:inverter_replacement_year in fieldnames(typeof(p.s.storage.raw_inputs[b])))
            continue
        end
        future_cost_inverter = p.s.storage.raw_inputs[b].replace_cost_per_kw * value.(m[Symbol("dvStoragePower"*_n)])[b]
        future_cost_storage = p.s.storage.raw_inputs[b].replace_cost_per_kwh * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
        future_cost += future_cost_inverter + future_cost_storage

        present_cost += future_cost_inverter * (1 - p.s.financial.owner_tax_pct) / 
            ((1 + p.s.financial.owner_discount_pct)^p.s.storage.raw_inputs[b].inverter_replacement_year)
        present_cost += future_cost_storage * (1 - p.s.financial.owner_tax_pct) / 
            ((1 + p.s.financial.owner_discount_pct)^p.s.storage.raw_inputs[b].battery_replacement_year)
    end
    return future_cost, present_cost
end


"""
    calculate_lcoe(p::REoptInputs, tech_results::Dict, tech::AbstractTech)

The Levelized Cost of Energy (LCOE) is calculated as annualized costs (capital and O+M translated to current value) 
divided by annuale energy output.
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
        discount_pct = p.s.financial.owner_discount_pct
        federal_tax_pct = p.s.financial.owner_tax_pct
    else
        discount_pct = p.s.financial.offtaker_discount_pct
        federal_tax_pct = p.s.financial.offtaker_tax_pct
    end

    capital_costs = new_kw * tech.installed_cost_per_kw # pre-incentive capital costs

    annual_om = new_kw * tech.om_cost_per_kw # NPV of O&M charges escalated over financial life

    om_series = [annual_om * (1+p.s.financial.om_cost_escalation_pct)^yr for yr in 1:years]
    npv_om = sum([om * (1.0/(1.0+discount_pct))^yr for (yr, om) in enumerate(om_series)])

    #Incentives as calculated in the spreadsheet, note utility incentives are applied before state incentives
    utility_ibi = min(capital_costs * tech.utility_ibi_pct, tech.utility_ibi_max)
    utility_cbi = min(new_kw * tech.utility_rebate_per_kw, tech.utility_rebate_max)
    state_ibi = min((capital_costs - utility_ibi - utility_cbi) * tech.state_ibi_pct, tech.state_ibi_max)
    state_cbi = min(new_kw * tech.state_rebate_per_kw, tech.state_rebate_max)
    federal_cbi = new_kw * tech.federal_rebate_per_kw
    ibi = utility_ibi + state_ibi  #total investment-based incentives
    cbi = utility_cbi + federal_cbi + state_cbi #total capacity-based incentives

    #calculate energy in the BAU case, used twice later on
    existing_energy_bau = get(tech_results, "year_one_energy_produced_kwh_bau", 0)

    #calculate the value of the production-based incentive stream
    npv_pbi = 0
    year_one_energy_produced = get(tech_results, "year_one_energy_produced_kwh", 0)
    degradation_pct = :degradation_pct in fieldnames(typeof(tech)) ? tech.degradation_pct : 0.0
    if tech.production_incentive_max_benefit > 0
        for yr in 1:years
            if yr < tech.production_incentive_years
                degredation_pct = (1- degradation_pct)^yr
                base_pbi = minimum([tech.production_incentive_per_kwh * 
                    (year_one_energy_produced - existing_energy_bau) * degredation_pct,  
                    tech.production_incentive_max_benefit * degredation_pct 
                ])
                npv_pbi += base_pbi * (1.0/(1.0+discount_pct))^(yr+1)
            end
        end
    end

    npv_federal_itc = 0
    federal_itc_basis = capital_costs - state_ibi - utility_ibi - state_cbi - utility_cbi - federal_cbi
    federal_itc_amount = tech.federal_itc_pct * federal_itc_basis
    npv_federal_itc = federal_itc_amount * (1.0/(1.0+discount_pct))

    depreciation_schedule = zeros(years)
    if tech.macrs_option_years in [5,7]
        if tech.macrs_option_years == 5
            schedule = p.s.financial.macrs_five_year
        elseif tech.macrs_option_years == 7
            schedule = p.s.financial.macrs_seven_year
        end
        macrs_bonus_basis = federal_itc_basis - (federal_itc_basis * tech.federal_itc_pct * tech.macrs_itc_reduction)
        macrs_basis = macrs_bonus_basis * (1 - tech.macrs_bonus_pct)
        for (i,r) in enumerate(schedule)
            if i-1 < length(depreciation_schedule)
                depreciation_schedule[i] = macrs_basis * r
            end
        end
        depreciation_schedule[1] += tech.macrs_bonus_pct * macrs_bonus_basis
    end

    tax_deductions = (om_series + depreciation_schedule) * federal_tax_pct
    npv_tax_deductions = sum([i* (1.0/(1.0+discount_pct))^yr for (yr,i) in enumerate(tax_deductions)])

    #we only care about the energy produced by new capacity in LCOE calcs
    annual_energy = year_one_energy_produced - existing_energy_bau
    npv_annual_energy = sum([annual_energy * (1.0/(1.0+discount_pct))^yr * 
        (1- degradation_pct)^(yr-1) for yr in 1:years])

    #LCOE is calculated as annualized costs divided by annualized energy
    lcoe = (capital_costs + npv_om - npv_pbi - cbi - ibi - npv_federal_itc - npv_tax_deductions ) / npv_annual_energy

    return round(lcoe, digits=4)
end