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
    r["lcc"] = round(value(m[Symbol("Costs"*_n)]) + 0.0001 * value(m[Symbol("MinChargeAdder"*_n)]))
    r["net_capital_costs_plus_om"] = round(
        value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)]) +
        value(m[Symbol("TotalPerUnitSizeOMCosts"*_n)]) * (1 - p.s.financial.owner_tax_pct), digits=0
    )
    r["net_capital_costs"] = round(value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)]), 
                                   digits=2)
    r["initial_capital_costs"] = initial_capex(m, p; _n=_n)
    r["initial_capital_costs_after_incentives"] = initial_capex_after_incentives(m, p, r["net_capital_costs"]; _n=_n)
    d["Financial"] = r
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
            initial_capex += p.s.storage.installed_cost_per_kw[b]  * value.(m[Symbol("dvStoragePower"*_n)])[b] + 
                             p.s.storage.installed_cost_per_kwh[b] * value.(m[Symbol("dvStorageEnergy"*_n)])[b]
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

    return round(initial_capex_after_incentives, digits=2)
end