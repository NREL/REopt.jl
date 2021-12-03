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

Create a convex relaxation for the bilinear product of two variables x*y by defining the McCormick
envelop. Also adds a new variable `varname` to the model `m` for the product x*y.
"""
function add_mccormick_constraints(m, varname::String, varindices::UnitRange{Int64},
    x::Vector{JuMP.VariableRef}, y::Vector{JuMP.VariableRef}, 
    xu::Vector{<:Real}, xl::Vector{<:Real}, yu::Vector{<:Real}, yl::Vector{<:Real})

    w = m[Symbol(varname)] = @variable(m, [varindices], base_name = varname)

    @constraint(m, [d in varindices],
        w[d] >= xl[d] * y[d] + x[d] * yl[d] - xl[d] * yl[d]
    )
    
    @constraint(m, [d in varindices],
        w[d] >= xu[d] * y[d] + x[d] * yu[d] - xu[d] * yu[d]
    )
    
    @constraint(m, [d in varindices],
        w[d] <= xl[d] * y[d] + x[d] * yu[d] - xl[d] * yu[d]
    )
    
    @constraint(m, [d in varindices],
        w[d] <= xu[d] * y[d] + x[d] * yl[d] - xu[d] * yl[d]
    )
    return w
end


function add_degradation_variables(m, p)
    days = 1:365*p.s.financial.analysis_years
    @variable(m, Eavg[days] >= 0)
    @variable(m, Eplus_sum[days] >= 0)
    @variable(m, Eminus_sum[days] >= 0)
    @variable(m, Emax[days] >= 0)
    @variable(m, Emin[days] >= 0)
end


function constrain_degradation_variables(m, p; b=:elec)
    days = 1:365*p.s.financial.analysis_years
    ts_per_day = 24 / p.hours_per_timestep
    ts_per_year = ts_per_day * 365
    for d in days
        ts0 = Int((ts_per_day * (d - 1) + 1) % ts_per_year)
        tsF = Int(ts_per_day * d % ts_per_year)
        if tsF == 0
            tsF = Int(ts_per_day * 365)
        end
        @constraint(m, 
            m[:Eavg][d] == 1/ts_per_day * sum(m[:dvStoredEnergy][b, ts] for ts in ts0:tsF)
        )
        @constraint(m, [ts = ts0:tsF],
            m[:Emax][d] >= m[:dvStoredEnergy][b, ts]
        )
        @constraint(m, [ts = ts0:tsF],
            m[:Emin][d] <= m[:dvStoredEnergy][b, ts]
        )
        @constraint(m,
            m[:Eplus_sum][d] == 
                sum(m[:dvProductionToStorage][b, t, ts] for t in p.techs.elec, ts in ts0:tsF) 
                + sum(m[:dvGridToStorage][b, ts] for ts in ts0:tsF)
        )
        @constraint(m,
            m[:Eminus_sum][d] == sum(m[:dvDischargeFromStorage][b, ts] for ts in ts0:tsF)
        )
    end
end


function get_battery_bounds_from_result_dict(p::REoptInputs, d::Dict)
    # TODO define the degradation terms in weekly values to reduce variables?
    days = 1:365*p.s.financial.analysis_years
    ts_per_day = 24 / p.hours_per_timestep
    ts_per_year = ts_per_day * 365
    soc = d["Storage"]["year_one_soc_series_pct"]
    Bkwh = d["Storage"]["size_kwh"]
    soc_kwh = Bkwh * soc
    soc_kwh_zero = vcat([p.s.storage.soc_init_pct[:elec] * Bkwh], soc_kwh)
    Eminus = [e < 0 ? abs(e) : 0 for e in diff(soc_kwh_zero)]
    Eplus = [e > 0 ? e : 0 for e in diff(soc_kwh_zero)]

    D = length(days)
    Emax_upper = zeros(D)
    Emax_lower = zeros(D)
    Emin_upper = zeros(D)
    Emin_lower = zeros(D)
    Eplus_sum_upper = zeros(D)
    Eplus_sum_lower = zeros(D)
    Eminus_sum_upper = zeros(D)
    Eminus_sum_lower = zeros(D)
    # TODO options for defining bounds? for example could just use Bkwh for Emax_upper in all days
    # instead of the optimal Emax_upper w/o degradation. However, it seems that with degradation 
    # would generally use the battery less then w/o degradation.
    for d in days
        ts0 = Int((ts_per_day * (d - 1) + 1) % ts_per_year)
        tsF = Int(ts_per_day * d % ts_per_year)
        if tsF == 0
            tsF = Int(ts_per_day * 365)
        end
        Emax_upper[d] = maximum(soc_kwh[ts0:tsF])
        # Emax_lower[d] = stays zero
        Emin_upper[d] = minimum(soc_kwh[ts0:tsF])
        # Emin_lower[d] = stays zero
        Eplus_sum_upper[d] = sum(Eplus[ts0:tsF])
        # Eplus_sum_lower[d] = stays zero
        Eminus_sum_upper[d] = sum(Eminus[ts0:tsF])
        # Eminus_sum_lower[d] = stays zero
    end
    return Dict(
        "Emax_upper" => Emax_upper, 
        "Emax_lower" => Emax_lower, 
        "Emin_upper" => Emin_upper, 
        "Emin_lower" => Emin_lower, 
        "Eplus_sum_upper" => Eplus_sum_upper, 
        "Eplus_sum_lower" => Eplus_sum_lower, 
        "Eminus_sum_upper" => Eminus_sum_upper, 
        "Eminus_sum_lower" => Eminus_sum_lower,
        "Bkwh" => Bkwh
    )
end


function add_degradation(m, p, d::Dict, k_cal::Float64, k_cyc::Float64; time_exponent=0.5, b=:elec)
    days = 1:365*p.s.financial.analysis_years
    @variable(m, SOH[days])

    #= 
    TODO create input struct for bounds to pass to add_mccormick_constraints?
    For now take the limits from previous REopt run in the Dict d.
    =#
    add_degradation_variables(m, p)
    constrain_degradation_variables(m, p; b=:elec)

    bounds = get_battery_bounds_from_result_dict(p, d)

    # TODO? one bilinear set for DODmax * EFC ?
    for bilinear_set in (
        (m[:Emax].data, m[:Eplus_sum].data, "Emax_Eplus_sum"),
        (m[:Emax].data, m[:Eminus_sum].data, "Emax_Eminus_sum"),
        (m[:Emin].data, m[:Eplus_sum].data, "Emin_Eplus_sum"),
        (m[:Emin].data, m[:Eminus_sum].data, "Emin_Eminus_sum"),
        )
        add_mccormick_constraints(m, bilinear_set[3], days,
            bilinear_set[1], bilinear_set[2], 
            bounds[bilinear_set[3][1:5]*"upper"], 
            bounds[bilinear_set[3][1:5]*"lower"], 
            bounds[bilinear_set[3][6:end]*"_upper"], 
            bounds[bilinear_set[3][6:end]*"_lower"]
        )
    end
    @constraint(m, SOH[1] == bounds["Bkwh"])
    @constraint(m, [d in 2:days[end]],
        SOH[d] == SOH[d-1] - time_exponent * k_cal * m[:Eavg][d-1] * d^(time_exponent-1) - k_cyc/(2*bounds["Bkwh"]) * 
                 (  m[:Emax_Eplus_sum][d-1] + m[:Emax_Eminus_sum][d-1] 
                  - m[:Emin_Eplus_sum][d-1] - m[:Emin_Eminus_sum][d-1])
    )
    @variable(m, soh_indicator[days], Bin)

    # @constraint(m, [d in days],
    #     soh_indicator[d] => {SOH[d] >= 0.8*bounds["Bkwh"]}
    # )
    # why do we need the opposite indicator ??? model does not hold the indicator constraint above
    @constraint(m, [d in days],
        !soh_indicator[d] => {SOH[d] <= 0.8*bounds["Bkwh"]}
    )
    # @variable(m, d_0p8 >= 0)
    @expression(m, d_0p8, sum(soh_indicator[d] for d in days))

    # build piecewise linear approximation of Ndays / d_0p8 - 1
    Ndays = days[end]
    points = (
        (0, 20),
        (Ndays/5, 4),
        (Ndays/4, 3),
        (Ndays/3, 2),
        (Ndays/2, 1),
        (3*Ndays/4, 1/3),
        (Ndays, 0.0)
    )
    point_pairs = ((pt1, pt2) for (pt1, pt2) in zip(points[1:end-1], points[2:end]))
    @variable(m, N_batt_replacements >= 0)
    for pair in point_pairs
        @constraint(m, 
            N_batt_replacements >= (pair[2][2] - pair[1][2]) / (pair[2][1] - pair[1][1]) * (d_0p8 - pair[1][1]) + pair[1][2]
        )
    end

    m[:Costs] += p.s.storage.installed_cost_per_kwh[:elec] /20 * N_batt_replacements
end
# TODO raise error for multisite with degradation

#=
Getting solutions with max size_kw=10000.0 with size_kwh = 0.0 ????


Gives storage cost with no benefit ???
julia> value(m[:TotalStorageCapCosts])
5.577452e6


Something to do with McCormick constraints or bounds? 
Model is choosing all zeros for bilinear terms but upper bounds sum to big numbers

julia> sum(bounds["Emin_upper"])
338509.69620000024

julia> sum(bounds["Emax_upper"])
567205.0800000001

julia> sum(bounds["Eplus_sum_upper"])
231140.01559999996

julia> sum(bounds["Eminus_sum_upper"])
231613.47559999992

soh = value.(m[:SOH]);
sohi = value.(m[:soh_indicator]);
bounds = REoptLite.get_battery_bounds_from_result_dict(p, d1);


julia> sum(value.(m[:dvGridToStorage])[:elec, :])
0.0

julia> sum(value.(m[:dvStoredEnergy][:elec,:]))
0.0

julia> sum(value.(m[:dvDischargeFromStorage][:elec,:]))
0.0



julia> value(m[:Costs])
1.8479958589985766e7

=# 