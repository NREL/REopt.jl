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
    ts_per_day = 24 / p.hours_per_time_step
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
                p.hours_per_time_step * (
                    sum(m[:dvProductionToStorage][b, t, ts] for t in p.techs.elec, ts in ts0:tsF) 
                    + sum(m[:dvGridToStorage][b, ts] for ts in ts0:tsF)
                )
        )
        @constraint(m,
            m[:Eminus_sum][d] == p.hours_per_time_step * sum(m[:dvDischargeFromStorage][b, ts] for ts in ts0:tsF)
        )
        @constraint(m,
            m[:EFC][d] == (m[:Eplus_sum][d] + m[:Eminus_sum][d]) / 2
        )
    end
end


"""
    add_degradation(m, p; b="ElectricStorage")

NOTE the average SOC and EFC variables are in absolute units. For example, the SOH variable starts 
    at the battery capacity in kWh.
"""
function add_degradation(m, p; b="ElectricStorage")

    # Indices
    days = 1:365*p.s.financial.analysis_years
    months = 1:p.s.financial.analysis_years*12

    strategy = p.s.storage.attr[b].degradation.maintenance_strategy

    if isempty(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh)
        function pwf_bess_replacements(day::Int)
            (1-p.s.storage.attr[b].degradation.installed_cost_per_kwh_declination_rate)^(day/365) / 
            (1+p.s.financial.owner_discount_pct)^(day/365)
        end
        # for the augmentation strategy the maintenance cost curve (function of time) starts at 
        # 80% of the installed cost since we are not replacing the entire battery
        f = strategy == "augmentation" ? 0.8 : 1.0
        p.s.storage.attr[b].degradation.maintenance_cost_per_kwh = [ f * 
            p.s.storage.attr[b].installed_cost_per_kwh * pwf_bess_replacements(d) for d in days[1:end-1]
        ]
    end

    @assert(length(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh) == length(days) - 1,
        "The degradation maintenance_cost_per_kwh must have a length of $(length(days)-1)."
    )

    @variable(m, SOH[days])

    add_degradation_variables(m, p)
    constrain_degradation_variables(m, p, b=b)

    @constraint(m, [d in 2:days[end]],
        SOH[d] == SOH[d-1] - p.hours_per_time_step * (
            p.s.storage.attr[b].degradation.calendar_fade_coefficient * 
            p.s.storage.attr[b].degradation.time_exponent * 
            m[:Eavg][d-1] * d^(p.s.storage.attr[b].degradation.time_exponent-1) + 
            p.s.storage.attr[b].degradation.cycle_fade_coefficient * m[:EFC][d-1]
        )
    )
    # NOTE SOH can be negative

    @constraint(m, SOH[1] == m[:dvStorageEnergy][b])
    # NOTE SOH is _not_ normalized, and has units of kWh

    if strategy == "replacement"
        # TODO update docs
        #=
        When the battery degrades to 80% of purchased capacity it is replaced.
        Multiple replacements could be necessary within the analysis period.
        (The SOH is calculated for the analysis period, but not for multiple batteries.)
        So we construct a cost as a function of months that accounts for the number of replacements.
        (We use months instead of days to reduce the number of integer variables required).

        The replacment cost in a given month is: [outdated, # TODO update this paragraph]
        1. the maintenance_cost_per_kwh in (approximately) the 15th day of the month multiplied with
        2. the number of replacements required given the first month that the battery must be replaced.
        
        The number of months is analysis_years * 12.

        The first month that the battery is replaced is determined by m_0p8, which is the integer 
        number of months that the SOH is at least 80% of the purchased capacity. m_0p8 has to be incremented
        by 1 to account for the month where SOH drops < 80%
        
        We define a binary for each month and only allow one month to be chosen.
        =#
        
        @warn "Adding binary and indicator constraints for 
         ElectricStorage.degradation.maintenance_strategy = \"replacement\". 
         Not all solvers support indicators and some are slow with integers."
        
        ## Create binary variables
        @variable(m, soh_indicator[months], Bin) # track SOH levels, 1 if SOH >= 80%, 0 otherwise
        @variable(m, bmth[months], Bin) # track which month SOH indicator drops to < 80%

        # Sum the # of months where SOH >= 80%, call this m_0p8.
        @expression(m, m_0p8, sum(soh_indicator[mth] for mth in months))

        #=
        Check the SOH levels at **end** of each month. If SOH < 80%, then soh_indicator is 0, else soh_indicator is 1.
            Assume SOH >= 80% in beginning of month 1.
            While SOH >= 80% at end of a month, soh_indicator remains 1.
            If SOH transitions from >= 80% to <80%, soh_indicator switches to 0 from that month onwards for remaining months
            Sp, m_0p8 needs to be incremented by 1 to account for the month when SOH becomes unhealthy

            30.4167 is average # of days per month
        =#
        @constraint(
            m,
            [mth in months],
            soh_indicator[mth] =>
            {
                SOH[Int(round(mth*30.4167, digits=0))] >= 0.8*m[:dvStorageEnergy][b]
            }
        )
        # If soh_indicator in last month is 0 (i.e. we droppe below 80% capacity), there has to be 1 replacement. If 
        # soh_indicator in last month == 1 (no replacement needed), sum of all bmth binary variables == 0
        @constraint(m, sum(bmth[mth] for mth in months) == 1-soh_indicator[length(months)])

        # if last value in SOH indicator is 0, then set replacement month equal to m_0p8 +1
        # Edge case: if replacement happens in month 300, m_0p8 = 299 since it wont account for the month when SOH switches to unhealthy.
        @constraint(
            m,
            !soh_indicator[length(months)] =>
            {
                sum(mth*bmth[mth] for mth in months) == m_0p8 + 1
            }
        )

        #=
        number of replacments as function of d_0p8
         ^
         |
        4-    ------
         |
        3-          -------
         |
        2-                 -----
         |
        1-                      -------------------
         |
         ------|----|------|----|-----------------|->  d_0p8
              N/5  N/4    N/3  N/2                N = 12*analysis_years
        
        The above curve is multiplied by the discount factor for all replacement days and installed_cost_per_kwh to create the cost coefficients
        =#
        c = zeros(length(months))  # initialize cost coefficients
        s = zeros(length(months))  # initialize cost coefficients for residual value
        N = 365*p.s.financial.analysis_years
        for mth in months
            day = Int(round((mth-1)*30.4167 + 15, digits=0))
            batt_replace_count = Int(ceil(N/day - 1)) # number of batt replacements in analysis period
            # maint_cost = sum(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[day*i] for i in 1:batt_replace_count)
            # c[mth] = maint_cost
            disc_factor = sum(pwf_bess_replacements(day*i) for i in 1:batt_replace_count) # here we can instead index into maintenance_cost_per_kwh vector, sum all costs, and set them equal to c[mth] in next line
            c[mth] = p.s.storage.attr[b].installed_cost_per_kwh * disc_factor

            #= Salvage value logic and example
            If replacement happens in month 145, then we will do 2 replacements, but only use last battery for ~6% of its expected life
            In this case, salvage factor comes to 93.1%. This is the useful proportion of BESS life left after analysis period ends.
            We account for this by creating a salvage value cost vector and subtracting it from the objective (i.e. maximizing this value).
            
            Logic:
                Assuming the same replacement period as math, calculate the remaining fraction of useful life after analysis period
                The BESS residual value is product of last day's maintenance_cost_per_kwh and salvage_factor
                Set salvaged_value for that mth.
            =#
            salvage_factor = 1 - (p.s.financial.analysis_years*12/mth - floor(p.s.financial.analysis_years*12/mth))
            salvaged_value = p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[end]*salvage_factor
            s[mth] = salvaged_value
            
        end

        #=
        -> linearize the product of bmth & m[:dvStorageEnergy][b]
        For all months
            0 <= bmth_BkWh <= dvStorageEnergy <= M (when bmth is true)

            if bmth is 0, bmth_BkWh = 0. if bmth is 1, bmth_BkWh can equal m[:dvStorageEnergy][b]
        =# 
        M = p.s.storage.attr[b].max_kwh  # the big M
        @variable(m, 0 <= bmth_BkWh[months])
        @constraint(m, [mth in months], bmth_BkWh[mth] <= m[:dvStorageEnergy][b])
        @constraint(m, [mth in months], bmth_BkWh[mth] <= M * bmth[mth])
        @constraint(m, [mth in months], bmth_BkWh[mth] >= m[:dvStorageEnergy][b] - M*(1-bmth[mth]))

        # add replacment cost to objective
        @expression(m, degr_cost, sum(c[mth] * bmth_BkWh[mth] for mth in months))

        # create salvage value expression for objective
        @expression(m, salv_value, sum(s[mth] * bmth_BkWh[mth] for mth in months))

    elseif strategy == "augmentation"

        @expression(m, degr_cost,
            sum(
                p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[d-1] * (SOH[d-1] - SOH[d])
                for d in days[2:end]
            )
        )
        # add augmentation cost to objective
        # maintenance_cost_per_kwh must have length == length(days) - 1, i.e. starts on day 2

        # create salvage value expression for objective, all 0s since we have no salvage value
        s = zeros(length(months))
        @expression(m, salv_value, sum(s[mth] for mth in months))

    else
        @error "Battery maintenance strategy $strategy is not supported. Choose from augmentation and replacement."
    end
    @objective(m, Min, m[:Costs] + m[:degr_cost] - m[:salv_value])
    
    # NOTE adding to Costs expression does not modify the objective function
 end
# TODO raise error for multisite with degradation
