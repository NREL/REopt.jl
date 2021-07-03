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

function annuity(years::Int, rate_escalation::Float64, rate_discount::Float64)
    """
        this formulation assumes cost growth in first period
        i.e. it is a geometric sum of (1+rate_escalation)^n / (1+rate_discount)^n
        for n = 1, ..., years
    """
    x = (1 + rate_escalation) / (1 + rate_discount)
    if x != 1
        pwf = round(x * (1 - x^years) / (1 - x), digits=5)
    else
        pwf = years
    end
    return pwf
end


function levelization_factor(years::Int, rate_escalation::Float64, rate_discount::Float64, 
    rate_degradation::Float64)
    #=
    NOTE: levelization_factor for an electricity producing tech is the ratio of:
    - an annuity with an escalation rate equal to the electricity cost escalation rate, starting year 1,
        and a negative escalation rate (the tech's degradation rate), starting year 2
    - divided by an annuity with an escalation rate equal to the electricity cost escalation rate (pwf_e).
    Both use the offtaker's discount rate.
    levelization_factor is multiplied by each use of dvRatedProduction in reopt.jl 
        (except dvRatedProduction[t,ts] == dvSize[t] ∀ ts).
    This way the denominator is cancelled in reopt.jl when accounting for the value of energy produced
    since each value constraint uses pwf_e.

    :param analysis_period: years
    :param rate_escalation: escalation rate
    :param rate_discount: discount rate
    :param rate_degradation: positive degradation rate
    :return: present worth factor with escalation (inflation, or degradation if negative)
    NOTE: assume escalation/degradation starts in year 2
    =#
    num = 0
    for yr in range(1, stop=years)
        num += (1 + rate_escalation)^(yr) / (1 + rate_discount)^yr * (1 - rate_degradation)^(yr - 1)
    end
    den = annuity(years, rate_escalation, rate_discount)

    return num/den
end


function effective_cost(;
    itc_basis::Float64, 
    replacement_cost::Float64, 
    replacement_year::Int,
    discount_rate::Float64, 
    tax_rate::Float64, 
    itc::Float64,
    macrs_schedule::Array{Float64,1}, 
    macrs_bonus_pct::Float64, 
    macrs_itc_reduction::Float64,
    rebate_per_kw::Float64=0.0,
    )

    """ effective PV and battery prices with ITC and depreciation
        (i) depreciation tax shields are inherently nominal --> no need to account for inflation
        (ii) ITC and bonus depreciation are taken at end of year 1
        (iii) battery replacement cost: one time capex in user defined year discounted back to t=0 with r_owner
        (iv) Assume that cash incentives reduce ITC basis
        (v) Assume cash incentives are not taxable, (don't affect tax savings from MACRS)
        (vi) Cash incentives should be applied before this function into "itc_basis".
             This includes all rebates and percentage-based incentives besides the ITC
    """

    # itc reduces depreciable_basis
    depr_basis = itc_basis * (1 - macrs_itc_reduction * itc)

    # Bonus depreciation taken from tech cost after itc reduction ($/kW)
    bonus_depreciation = depr_basis * macrs_bonus_pct

    # Assume the ITC and bonus depreciation reduce the depreciable basis ($/kW)
    depr_basis -= bonus_depreciation

    # Calculate replacement cost, discounted to the replacement year accounting for tax deduction
    replacement = replacement_cost * (1-tax_rate) / ((1 + discount_rate)^replacement_year)

    # Compute savings from depreciation and itc in array to capture NPV
    tax_savings_array = [0.0]
    for (idx, macrs_rate) in enumerate(macrs_schedule)
        depreciation_amount = macrs_rate * depr_basis
        if idx == 1
            depreciation_amount += bonus_depreciation
        end
        taxable_income = depreciation_amount
        push!(tax_savings_array, taxable_income * tax_rate)
    end

    # Add the ITC to the tax savings
    tax_savings_array[2] += itc_basis * itc

    # Compute the net present value of the tax savings
    tax_savings = npv(discount_rate, tax_savings_array)

    # Adjust cost curve to account for itc and depreciation savings ($/kW)
    cap_cost_slope = itc_basis - tax_savings + replacement - rebate_per_kw

    # Sanity check
    if cap_cost_slope < 0
        cap_cost_slope = 0
    end

    return round(cap_cost_slope, digits=4)
end


function dictkeys_tosymbols(d::Dict)
    d2 = Dict()
    for (k, v) in d
        if k in ["loads_kw", "prod_factor_series_kw"] && !isempty(v)
            try
                v = convert(Array{Real, 1}, v)
            catch
                @warn "Unable to convert $k to an Array{Real, 1}"
            end
        end
        d2[Symbol(k)] = v
    end
    return d2
end

function filter_dict_to_match_struct_field_names(d::Dict, s::DataType)
    f = fieldnames(s)
    d2 = Dict()
    for k in f
        if haskey(d, k)
            d2[k] = d[k]
        else
            @warn "dict is missing struct field $k"
        end
    end
    return d2
end


function npv(rate::Float64, cash_flows::Array)
    npv = cash_flows[1]
    for (y, c) in enumerate(cash_flows[2:end])
        npv += c/(1+rate)^y
    end
    return npv
end
