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
    @variable(m, EFC[days] >= 0)
end


function constrain_degradation_variables(m, p; b="ElectricStorage")
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
    end
end


"""

NOTE the average SOC and EFC variables are in absolute units. For example, the SOH variable starts 
    at the battery capacity in kWh.
"""
function add_degradation(m, p; 
        time_exponent=0.5, 
        b="ElectricStorage"
    )
    days = 1:365*p.s.financial.analysis_years
    strategy = p.s.storage.attr[b].degradation.maintenance_strategy

    if isempty(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh)
        function pwf(day::Int)
            (1+p.s.storage.attr[b].degradation.installed_cost_per_kwh_declination_rate)^(day/365) / 
            (1+p.s.financial.owner_discount_pct)^(day/365)
        end
        # for the augmentation strategy the maintenance cost curve (function of time) starts at 
        # 80% of the installed cost since we are not replacing the entire battery
        f = strategy == :augmentation ? 0.8 : 1.0
        p.s.storage.attr[b].degradation.maintenance_cost_per_kwh = [ f * 
            p.s.storage.attr[b].installed_cost_per_kwh * pwf(d) for d in days[1:end-1]
        ]
    end

    @assert(length(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh) == length(days) - 1,
        "The degradation maintenance_cost_per_kwh must have a length of $(length(days)-1)."
    )

    @variable(m, SOH[days])

    add_degradation_variables(m, p)
    constrain_degradation_variables(m, p, b=b)

    @constraint(m, [d in 2:days[end]],
        SOH[d] == SOH[d-1] - p.hours_per_timestep * (
            p.s.storage.attr[b].degradation.calendar_fade_coefficient * time_exponent * 
            m[:Eavg][d-1] * d^(time_exponent-1) + 
            p.s.storage.attr[b].degradation.cycle_fade_coefficient * m[:EFC][d-1]
        )
    )
    # NOTE SOH can be negative

    @constraint(m, SOH[1] == m[:dvStorageEnergy][b])
    # NOTE SOH is _not_ normalized, and has units of kWh

    if strategy == :replacement
        @error("cannot make replacment strategy fit MILP format")
        @variable(m, soh_indicator[days], Bin)

        @constraint(m, [d in days],
            soh_indicator[d] => {SOH[d] >= 0.8*m[:dvStorageEnergy][b]}
        )
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

        # add replacment cost to objective
        @expression(m, degr_cost,
            p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[d_0p8] * diff(SOH) ### will not work!? bilinear
        )

    elseif strategy == :augmentation

        @expression(m, degr_cost,
            sum(
                p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[d-1] * (SOH[d-1] - SOH[d])
                for d in days[2:end]
            )
        )
        # add augmentation cost to objective
        # maintenance_cost_per_kwh must have length == length(days) - 1, i.e. starts on day 2
    else
        @error "Battery maintenance strategy $strategy is not supported. Choose from augmentation and replacement."
    end

    @objective(m, Min, m[:Costs] + m[:degr_cost])
    
    # TODO scale battery replacement cost
    # NOTE adding to Costs expression does not modify the objective function
    # set_optimizer_attribute(m, "MIPRELSTOP", 0.01)
    # TODO increase threads?
end
# TODO raise error for multisite with degradation
