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


function add_degradation_variables(m, p)
    days = 1:365*p.s.financial.analysis_years
    @variable(m, Eavg[days] >= 0)
    @variable(m, Eplus_sum[days] >= 0)
    @variable(m, Eminus_sum[days] >= 0)
    @variable(m, Emax[days] >= 0)
    @variable(m, Emin[days] >= 0)
    @variable(m, EFC[days] >= 0)
    @variable(m, DODmax[days] >= 0)
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
        @constraint(m,
            m[:EFC][d] == (m[:Eplus_sum][d] + m[:Eminus_sum][d]) / 2
        )
        @constraint(m,
            m[:DODmax][d] == m[:Emax][d] - m[:Emin][d]
        )
    end
end


"""

Assumptions:
- effectively normalizing average SOC, EFC, and DODmax by the battery capacity from a REopt solution w/o degradation
    - TODO what if no battey in w/o degradation results?
    - NOTE the average SOC, EFC, and DODmax variables are in absolute units making the SOH variable start at the 
        battery capacity w/o degradation
"""
function add_degradation(m, p, Qo::Float64, k_cal::Float64, k_cyc::Float64, k_dod::Float64; time_exponent=0.5, b=:elec)
    days = 1:365*p.s.financial.analysis_years
    @variable(m, SOH[days])

    add_degradation_variables(m, p)
    constrain_degradation_variables(m, p, b=b)

    @constraint(m, [d in 2:days[end]],
        SOH[d] == SOH[d-1] - p.hours_per_timestep * (
            k_cal * time_exponent * m[:Eavg][d-1] * d^(time_exponent-1) 
            + k_cyc * m[:EFC][d-1]
            + k_dod * m[:DODmax][d-1]
        )
    )
    # NOTE SOH can be negative

    @constraint(m, SOH[1] == m[:dvStorageEnergy][b])
    # NOTE SOH is _not_ normalized, and has units of kWh

    @variable(m, soh_indicator[days], Bin)

    # @constraint(m, [d in days],
    #     soh_indicator[d] => {SOH[d] >= 0.8*Qo}
    # )
    # @expression(m, d_0p8, sum(soh_indicator[d] for d in days))

    # # build piecewise linear approximation of Ndays / d_0p8 - 1
    # Ndays = days[end]
    # points = (
    #     (0, 20),
    #     (Ndays/5, 4),
    #     (Ndays/4, 3),
    #     (Ndays/3, 2),
    #     (Ndays/2, 1),
    #     (3*Ndays/4, 1/3),
    #     (Ndays, 0.0)
    # )
    # point_pairs = ((pt1, pt2) for (pt1, pt2) in zip(points[1:end-1], points[2:end]))
    # @variable(m, N_batt_replacements >= 0)
    # for pair in point_pairs
    #     @constraint(m, 
    #         N_batt_replacements >= (pair[2][2] - pair[1][2]) / (pair[2][1] - pair[1][1]) * (d_0p8 - pair[1][1]) + pair[1][2]
    #     )
    # end
    
    # TODO scale battery replacement cost
    # NOTE adding to Costs expression does not modify the objective function
    @objective(m, Min, 
        m[:Costs] + p.s.storage.installed_cost_per_kwh[:elec]/5 * (SOH[1] - SOH[end])
    )
    set_optimizer_attribute(m, "MIPRELSTOP", 0.01)
    # TODO increase threads?
end
# TODO raise error for multisite with degradation
