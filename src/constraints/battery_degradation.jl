# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.


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
    days = 1:365*p.s.financial.analysis_years
    strategy = p.s.storage.attr[b].degradation.maintenance_strategy

    if isempty(p.s.storage.attr[b].degradation.maintenance_cost_per_kwh)
        function pwf(day::Int)
            (1-p.s.storage.attr[b].degradation.installed_cost_per_kwh_declination_rate)^(day/365) / 
            (1+p.s.financial.owner_discount_rate_fraction)^(day/365)
        end
        # for the augmentation strategy the maintenance cost curve (function of time) starts at 
        # 80% of the installed cost since we are not replacing the entire battery
        f = strategy == "augmentation" ? 0.8 : 1.0
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
        #=
        When the battery degrades to 80% of purchased capacity it is replaced.
        Multiple replacements could be necessary within the analysis period.
        (The SOH is calculated for the analysis period, but not for multiple batteries.)
        So we construct a cost as a function of months that accounts for the number of replacements.
        (We use months instead of days to reduce the number of integer variables required).

        The replacment cost in a given month is:
        1. the maintenance_cost_per_kwh in (approximately) the 15th day of the month multiplied with
        2. the number of replacements required given the first month that the battery must be replaced.
        The number of months is analysis_years * 12.
        The first month that the battery is replaced is determined by d_0p8, which is the integer 
        number of days that the SOH is at least 80% of the purchased capacity.
        We define a binary for each month and only allow one month to be chosen.
        =#
        
        # define d_0p8
        @warn "Adding binary and indicator constraints for 
         ElectricStorage.degradation.maintenance_strategy = \"replacement\". 
         Not all solvers support indicators and some are slow with integers."
        @variable(m, soh_indicator[days], Bin)
        if p.s.settings.solver_id in INDICATOR_COMPATIBLE_SOLVERS
            @constraint(m, [d in days],
                soh_indicator[d] => {SOH[d] >= 0.8*m[:dvStorageEnergy][b]}
            )
        else
            @constraint(m, [d in days],
                SOH[d] >= 0.8*m[:dvStorageEnergy][b] - soh_indicator[d]*p.s.storage.attr[b].max_kwh
            )
        end
        @expression(m, d_0p8, sum(soh_indicator[d] for d in days))

        # define binaries for the finding the month that battery must be replaced
        months = 1:p.s.financial.analysis_years*12
        @variable(m, bmth[months], Bin)
        # can only pick one month (or no month if SOH is >= 80% in last day)
        @constraint(m, sum(bmth[mth] for mth in months) == 1-soh_indicator[length(days)])
        # the month picked is at most the month in which the SOH hits 80%
        @constraint(m, sum(mth*bmth[mth] for mth in months) <= d_0p8 / 30.42)
        # 30.42 is the average number of days in a month

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
              N/5  N/4    N/3  N/2                N = 365*analysis_years
        
        The above curve is multiplied by the maintenance_cost_per_kwh to create the cost coefficients
        =#
        c = zeros(length(months))  # initialize cost coefficients
        N = 365*p.s.financial.analysis_years
        for mth in months
            day = Int(round((mth-1)*30.42 + 15, digits=0))
            c[mth] = p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[day] *
                ceil(N/day - 1)
        end

        # linearize the product of bmth & m[:dvStorageEnergy][b]
        M = p.s.storage.attr[b].max_kwh  # the big M
        @variable(m, 0 <= bmth_BkWh[months])
        @constraint(m, [mth in months], bmth_BkWh[mth] <= m[:dvStorageEnergy][b])
        @constraint(m, [mth in months], bmth_BkWh[mth] <= M * bmth[mth])
        @constraint(m, [mth in months], bmth_BkWh[mth] >= m[:dvStorageEnergy][b] - M*(1-bmth[mth]))

        # add replacment cost to objective
        @expression(m, degr_cost,
            sum(c[mth] * bmth_BkWh[mth] for mth in months)
        )

    elseif strategy == "augmentation"

        @expression(m, degr_cost,
            sum(
                p.s.storage.attr[b].degradation.maintenance_cost_per_kwh[d-1] * (SOH[d-1] - SOH[d])
                for d in days[2:end]
            )
        )
        # add augmentation cost to objective
        # maintenance_cost_per_kwh must have length == length(days) - 1, i.e. starts on day 2
    else
        throw(@error("Battery maintenance strategy $strategy is not supported. Choose from augmentation and replacement."))
    end

    @objective(m, Min, m[:Costs] + m[:degr_cost])
    
    # NOTE adding to Costs expression does not modify the objective function
 end
# TODO raise error for multisite with degradation
