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
# https://discourse.julialang.org/t/vector-of-matrices-vs-multidimensional-arrays/9602/5
# 5d2360465457a3f77ddc131e has TOU demand
# 59bc22705457a3372642da67 has monthly tiered demand (no TOU demand)

"""
    Base.@kwdef struct URDBrate

Contains some of the data for ElectricTariff
"""
struct URDBrate
    energy_rates::Array{Float64,2}  # time X tier
    energy_tier_limits::Array{Real,1}
    n_energy_tiers::Int

    n_monthly_demand_tiers::Int
    monthly_demand_tier_limits::Array{Real,1}
    monthly_demand_rates::Array{Float64,2}  # month X tier

    n_tou_demand_tiers::Int
    tou_demand_tier_limits::Array{Real,1}
    tou_demand_rates::Array{Float64,2}  # ratchet X tier
    tou_demand_ratchet_timesteps::Array{Array{Int64,1},1}  # length = n_tou_demand_ratchets

    demand_lookback_months::AbstractArray{Int,1}
    demand_lookback_percent::Float64
    demand_lookback_range::Int

    fixed_monthly_charge::Float64
    annual_min_charge::Float64
    min_monthly_charge::Float64
end


"""
    URDBrate(urdb_label::String, year::Int=2019; time_steps_per_hour=1)

download URDB dict, parse into reopt inputs, return URDBrate struct.
    year is required to align weekday/weekend schedules.
"""
function URDBrate(urdb_label::String, year::Int=2019; time_steps_per_hour=1)
    urdb_response = download_urdb(urdb_label)
    URDBrate(urdb_response, year; time_steps_per_hour=time_steps_per_hour)
end


"""
    URDBrate(util_name::String, rate_name::String, year::Int=2019; time_steps_per_hour=1)

download URDB dict, parse into reopt inputs, return URDBrate struct.
    year is required to align weekday/weekend schedules.
"""
function URDBrate(util_name::String, rate_name::String, year::Int=2019; time_steps_per_hour=1)
    urdb_response = download_urdb(util_name, rate_name)
    URDBrate(urdb_response, year; time_steps_per_hour=time_steps_per_hour)
end


"""
    URDBrate(urdb_response::Dict, year::Int)

process URDB response dict, parse into reopt inputs, return URDBrate struct.
    year is required to align weekday/weekend schedules.
"""
function URDBrate(urdb_response::Dict, year::Int=2019; time_steps_per_hour=1)

    demand_min = get(urdb_response, "peakkwcapacitymin", 0.0)  # TODO add check for site min demand against tariff?

    n_monthly_demand_tiers, monthly_demand_tier_limits, monthly_demand_rates,
      n_tou_demand_tiers, tou_demand_tier_limits, tou_demand_rates, tou_demand_ratchet_timesteps =
      parse_demand_rates(urdb_response, year)

    energy_rates, energy_tier_limits, n_energy_tiers = parse_urdb_energy_costs(urdb_response, year)

    fixed_monthly_charge, annual_min_charge, min_monthly_charge = parse_urdb_fixed_charges(urdb_response)


    demand_lookback_months, demand_lookback_percent, demand_lookback_range = parse_urdb_lookback_charges(urdb_response)

    URDBrate(
        energy_rates,
        energy_tier_limits,
        n_energy_tiers,

        n_monthly_demand_tiers,
        monthly_demand_tier_limits,
        monthly_demand_rates,

        n_tou_demand_tiers,
        tou_demand_tier_limits,
        tou_demand_rates,
        tou_demand_ratchet_timesteps,

        demand_lookback_months,
        demand_lookback_percent,
        demand_lookback_range,

        fixed_monthly_charge,
        annual_min_charge,
        min_monthly_charge,
    )
end


function download_urdb(urdb_label::String; version::Int=8)
    url = string("https://api.openei.org/utility_rates", "?api_key=", urdb_key,
                "&version=", version , "&format=json", "&detail=full",
                "&getpage=", urdb_label
    )
    response = nothing
    try
        @info "Checking URDB for " urdb_label
        r = HTTP.get(url, require_ssl_verification=false)  # cannot verify on NREL VPN
        response = JSON.parse(String(r.body))
        if r.status != 200
            error("Bad response from URDB: $(response["errors"])")  # TODO URDB has "errors"?
        end
    catch e
        error("Error occurred :$(e)")
    end

    rates = response["items"]  # response['items'] contains a vector of dicts
    if length(rates) == 0
        error("Could not find $(urdb_label) in URDB.")
    end
    if rates[1]["label"] == urdb_label
        return rates[1]
    else
        error("Could not find $(urdb_label) in URDB.")
    end
end


function download_urdb(util_name::String, rate_name::String; version::Int=8)
    url = string("https://api.openei.org/utility_rates", "?api_key=", urdb_key,
                "&version=", version , "&format=json", "&detail=full",
                "&ratesforutility=", replace(util_name, "&" => "%26")
    )
    response = nothing
    try
        @info "Checking URDB for " rate_name
        r = HTTP.get(url, require_ssl_verification=false)  # cannot verify on NREL VPN
        response = JSON.parse(String(r.body))
        if r.status != 200
            error("Bad response from URDB: $(response["errors"])")  # TODO URDB has "errors"?
        end
    catch e
        error("Error occurred :$(e)")
    end

    rates = response["items"]  # response['items'] contains a vector of dicts
    if length(rates) == 0
        error("Could not find $(rate_name) in URDB.")
    end

    matched_rates = []
    start_dates = []

    for rate in rates
        if contains(rate_name, rate["name"])
            push!(matched_rates, rate)  # urdb can contain multiple rates of same name
            if "startdate" in keys(rate)
                push!(start_dates, rate["startdate"])
            end
        end
    end

    # find the newest rate of those that match the rate_name
    newest_index = 1  # covers the case where one rate is returned without a "startdate"
    if length(start_dates) > 1 && length(start_dates) == length(matched_rates)
        _, newest_index = findmax(start_dates)
    end
    
    if length(matched_rates) == 0
        error("Could not find $(rate_name) in URDB.")
    end

    return matched_rates[newest_index]
end


"""
    parse_urdb_energy_costs(d::Dict, year::Int; time_steps_per_hour=1, bigM = 1.0e8)

use URDB dict to return rates, energy_cost_vector, energy_tier_limits_kwh where:
    - rates is vector summary of rates within URDB (used for average rates when necessary)
    - energy_cost_vector is a vector of vectors with inner vectors for each energy rate tier,
        inner vectors are costs in each time step
    - energy_tier_limits_kwh is a vector of upper kWh limits for each energy tier
"""
function parse_urdb_energy_costs(d::Dict, year::Int; time_steps_per_hour=1, bigM = 1.0e8)
    if length(d["energyratestructure"]) == 0
        error("No energyratestructure in URDB response.")
    end
    # TODO check bigM (in multiple functions)
    energy_tiers = Float64[]
    for energy_rate in d["energyratestructure"]
        append!(energy_tiers, length(energy_rate))
    end
    energy_tier_set = Set(energy_tiers)
    if length(energy_tier_set) > 1
        @warn "energy periods contain different numbers of tiers, using limits of period with most tiers"
    end
    period_with_max_tiers = findall(energy_tiers .== maximum(energy_tiers))[1]
    n_energy_tiers = Int(maximum(energy_tier_set))

    rates = Float64[]
    energy_tier_limits_kwh = Float64[]
    non_kwh_units = false

    for energy_tier in d["energyratestructure"][period_with_max_tiers]
        # energy_tier is a dictionary, eg. {'max': 1000, 'rate': 0.07531, 'adj': 0.0119, 'unit': 'kWh'}
        energy_tier_max = get(energy_tier, "max", bigM)

        if "rate" in keys(energy_tier) || "adj" in keys(energy_tier)
            append!(energy_tier_limits_kwh, energy_tier_max)
        end

        if "unit" in keys(energy_tier)
            if string(energy_tier["unit"]) != "kWh"
                @warn "Using average rate in tier due to exotic units of " energy_tier["unit"]
                non_kwh_units = true
            end
        end

        append!(rates, get(energy_tier, "rate", 0) + get(energy_tier, "adj", 0))
    end

    if non_kwh_units
        rate_average = sum(rates) / maximum([length(rates), 1])
        n_energy_tiers = 1
        energy_tier_limits_kwh = Float64[bigM]
    end

    energy_cost_vector = Float64[]

    for tier in range(1, stop=n_energy_tiers)

        for month in range(1, stop=12)
            n_days = daysinmonth(Date(string(year) * "-" * string(month)))

            for day in range(1, stop=n_days)

                for hour in range(1, stop=24)

                    # NOTE: periods are zero indexed
                    if dayofweek(Date(year, month, day)) < 6  # Monday == 1
                        period = d["energyweekdayschedule"][month][hour] + 1
                    else
                        period = d["energyweekendschedule"][month][hour] + 1
                    end
                    # workaround for cases where there are different numbers of tiers in periods
                    n_tiers_in_period = length(d["energyratestructure"][period])
                    if n_tiers_in_period == 1
                        tier_use = 1
                    elseif tier > n_tiers_in_period
                        tier_use = n_tiers_in_period
                    else
                        tier_use = tier
                    end
                    if non_kwh_units
                        rate = rate_average
                    else
                        rate = get(d["energyratestructure"][period][tier_use], "rate", 0)
                    end
                    total_rate = rate + get(d["energyratestructure"][period][tier_use], "adj", 0)

                    for step in range(1, stop=time_steps_per_hour)  # repeat hourly rates intrahour
                        append!(energy_cost_vector, round(total_rate, digits=6))
                    end
                end
            end
        end
    end
    energy_rates = reshape(energy_cost_vector, (:, n_energy_tiers))
    return energy_rates, energy_tier_limits_kwh, n_energy_tiers
end


"""
    parse_demand_rates(d::Dict, year::Int; bigM=1.0e8)

Parse monthly ("flat") and TOU demand rates
    can modify URDB dict when there is inconsistent numbers of tiers in rate structures
"""
function parse_demand_rates(d::Dict, year::Int; bigM=1.0e8)

    if haskey(d, "flatdemandstructure")
        scrub_urdb_demand_tiers!(d["flatdemandstructure"])
        monthly_demand_tier_limits = parse_urdb_demand_tiers(d["flatdemandstructure"])
        n_monthly_demand_tiers = length(monthly_demand_tier_limits)
        monthly_demand_rates = parse_urdb_monthly_demand(d, n_monthly_demand_tiers)
    else
        monthly_demand_tier_limits = []
        n_monthly_demand_tiers = 1
        monthly_demand_rates = Array{Float64,2}(undef, 0, 0)
    end

    if haskey(d, "demandratestructure")
        scrub_urdb_demand_tiers!(d["demandratestructure"])
        tou_demand_tier_limits = parse_urdb_demand_tiers(d["demandratestructure"])
        n_tou_demand_tiers = length(tou_demand_tier_limits)
        ratchet_timesteps, tou_demand_rates = parse_urdb_tou_demand(d, year=year, n_tiers=n_tou_demand_tiers)
    else
        tou_demand_tier_limits = []
        n_tou_demand_tiers = 0
        ratchet_timesteps = []
        tou_demand_rates = Array{Float64,2}(undef, 0, 0)
    end

    return n_monthly_demand_tiers, monthly_demand_tier_limits, monthly_demand_rates,
           n_tou_demand_tiers, tou_demand_tier_limits, tou_demand_rates, ratchet_timesteps

end


"""
    scrub_urdb_demand_tiers!(A::Array)

validate flatdemandstructure and demandratestructure have equal number of tiers across periods
"""
function scrub_urdb_demand_tiers!(A::Array)
    if length(A) == 0
        return
    end
    len_tiers = Int[length(r) for r in A]
    len_tiers_set = Set(len_tiers)
    n_tiers = maximum(len_tiers_set)

    if length(len_tiers_set) > 1
        @warn """Demand rate structure has varying number of tiers in periods.
                 Making the number of tiers the same across all periods by repeating the last tier."""
        for (i, rate) in enumerate(A)
            n_tiers_in_period = length(rate)
            if n_tiers_in_period != n_tiers
                rate_new = rate
                last_tier = rate[n_tiers_in_period]
                for j in range(1, stop=n_tiers - n_tiers_in_period)
                    append!(rate_new, last_tier)
                end
                A[i] = rate_new
            end
        end
    end
end


"""
    parse_urdb_demand_tiers(A::Array; bigM=1.0e8)

set up and validate demand tiers
    returns demand_tiers::Array{Float64, n_tiers}
"""
function parse_urdb_demand_tiers(A::Array; bigM=1.0e8)
    if length(A) == 0
        return []
    end
    len_tiers = Int[length(r) for r in A]
    n_tiers = maximum(len_tiers)
    period_with_max_tiers = findall(len_tiers .== maximum(len_tiers))[1]

    # set up tiers and validate that the highest tier has the same value across periods
    demand_tiers = Dict()
    demand_maxes = Float64[]
    for period in range(1, stop=length(A))
        demand_max = Float64[]
        for tier in A[period]
            append!(demand_max, get(tier, "max", bigM))
        end
        demand_tiers[period] = demand_max
        append!(demand_maxes, demand_max[end])  # TODO should this be maximum(demand_max)?
    end

    # test if the highest tier is the same across all periods
    if length(Set(demand_maxes)) > 1
        @warn "Highest demand tiers do not match across periods: using max tier from largest set of tiers."
    end
    return demand_tiers[period_with_max_tiers]
end


"""
    parse_urdb_monthly_demand(d::Dict)

return monthly demand rates as array{month, tier}
"""
function parse_urdb_monthly_demand(d::Dict, n_tiers)
    if !haskey(d, "flatdemandmonths")
        return []
    end
    if length(d["flatdemandmonths"]) == 0
        return []
    end

    demand_rates = zeros(12, n_tiers)  # array(month, tier)
    for month in range(1, stop=12)
        period = d["flatdemandmonths"][month] + 1  # URDB uses zero-indexing
        rates = d["flatdemandstructure"][period]  # vector of dicts

        for (t, tier) in enumerate(rates)
            demand_rates[month, t] = round(get(tier, "rate", 0.0) + get(tier, "adj", 0.0), digits=6)
        end
    end
    return demand_rates
end


"""
    parse_urdb_tou_demand(d::Dict; year::Int, n_tiers::Int)

return array of arrary for ratchet time steps, tou demand rates array{ratchet, tier}
"""
function parse_urdb_tou_demand(d::Dict; year::Int, n_tiers::Int)
    if !haskey(d, "demandratestructure")
        return [], []
    end
    n_periods = length(d["demandratestructure"])
    ratchet_timesteps = Array[]
    rates_vec = Float64[]  # array(ratchet_num, tier), reshape later
    n_ratchets = 0  # counter

    for month in range(1, stop=12)
        for period in range(0, stop=n_periods)
            time_steps = get_tou_demand_steps(d, year=year, month=month, period=period-1)
            if length(time_steps) > 0  # can be zero! not every month contains same number of periods
                n_ratchets += 1
                append!(ratchet_timesteps, [time_steps])
                for (t, tier) in enumerate(d["demandratestructure"][period])
                    append!(rates_vec, round(get(tier, "rate", 0.0) + get(tier, "adj", 0.0), digits=6))
                end
            end
        end
    end
    rates = reshape(rates_vec, (:, n_tiers))  # Array{Float64,2}
    ratchet_timesteps = convert(Array{Array{Int64,1},1}, ratchet_timesteps)
    return ratchet_timesteps, rates
end


"""
    get_tou_demand_steps(d::Dict; year::Int, month::Int, period::Int, time_steps_per_hour=1)

return Array{Int, 1} for timesteps in ratchet (aka period)
"""
function get_tou_demand_steps(d::Dict; year::Int, month::Int, period::Int, time_steps_per_hour=1)
    step_array = Int[]
    start_step = 1
    start_hour = 1

    if month > 1
        plus_days = 0
        for m in range(1, stop=month-1)
            plus_days += daysinmonth(Date(string(year) * "-" * string(m)))
            if m == 2 && isleapyear(year)
                plus_days -= 1
            end
        end
        start_hour += plus_days * 24
        start_step = start_hour * time_steps_per_hour
    end

    hour_of_year = start_hour
    step_of_year = start_step

    for day in range(1, stop=daysinmonth(Date(string(year) * "-" * string(month))))
        for hour in range(1, stop=24)
            if dayofweek(Date(year, month, day)) < 6 &&
               d["demandweekdayschedule"][month][hour] == period
                append!(step_array, step_of_year)
            elseif dayofweek(Date(year, month, day)) > 5 &&
               d["demandweekendschedule"][month][hour] == period
                append!(step_array, step_of_year)
            end
            step_of_year += 1
        end
        hour_of_year += 1
    end
    return step_array
end


"""
    parse_urdb_fixed_charges(d::Dict)

return fixed_monthly, annual_min, min_monthly :: Float64
"""
function parse_urdb_fixed_charges(d::Dict)
    fixed_monthly = 0.0
    annual_min = 0.0
    min_monthly = 0.0

    # first try $/month, then check if $/day exists, as of 1/28/2020 there were only $/day and $month entries in the URDB
    if get(d, "fixedchargeunits", "") == "\$/month" 
        fixed_monthly = Float64(get(d, "fixedchargefirstmeter", 0.0))
    end
    if get(d, "fixedchargeunits", "") == "\$/day"
        fixed_monthly = Float64(get(d, "fixedchargefirstmeter", 0.0) * 30.4375)
        # scalar intended to approximate annual charges over 12 month period, derived from 365.25/12
    end

    if get(d, "minchargeunits", "") == "\$/month"
        min_monthly = Float64(get(d, "mincharge", 0.0))
        # first try $/month, then check if $/day or $/year exists, as of 1/28/2020 these were the only unit types in the urdb
    end
    if get(d, "minchargeunits", "") == "\$/day"
        min_monthly = Float64(get(d, "mincharge", 0.0) * 30.4375 )
        # scalar intended to approximate annual charges over 12 month period, derived from 365.25/12
    end

    if get(d, "minchargeunits", "") == "\$/year"
        annual_min = Float64(get(d, "mincharge", 0.0))
    end
    
    return fixed_monthly, annual_min, min_monthly
end


"""
    parse_urdb_lookback_charges(d::Dict)

URDB lookback fields:
- lookbackMonths
    - Type: array
    - Array of 12 booleans, true or false, indicating months in which lookbackPercent applies.
        If any of these is true, lookbackRange should be zero.
- lookbackPercent
    - Type: decimal
    - Lookback percentage. Applies to either lookbackMonths with value=1, or a lookbackRange.
- lookbackRange
    - Type: integer
    - Number of months for which lookbackPercent applies. If not 0, lookbackMonths values should all be 0.
"""
function parse_urdb_lookback_charges(d::Dict)
    lookback_months = get(d, "lookbackMonths", Int[])
    lookback_percent = Float64(get(d, "lookbackPercent", 0.0))
    lookback_range = Int64(get(d, "lookbackRange", 0.0))

    reopt_lookback_months = Int[]
    if lookback_range != 0 && length(lookback_months) == 12
        for mth in range(1, stop=12)
            if lookback_months[mth] == 1
                push!(reopt_lookback_months, mth)
            end
        end
    end
    return reopt_lookback_months, lookback_percent, lookback_range
end

function get_subset_of_urdb(rate::URDBrate, t_start::Integer, t_end::Integer)::Dict
    energy_rates = rate.energy_rates[t_start:t_end] # Just take the first tier until the model supports tiers
    
    # Export rates not presented in URDB, ignore

    # For now, assume the demand rates from the month of t_start - later update this to mix demand charges based on time intervals with multiple months (is the model aware?)
    month = month_of_hour(t_start)
    print("Month ", month, "\n")
    monthly_demand = rate.monthly_demand_rates[month:month]

    # What if different months have different numbers of periods?
    periods_per_month = floor(Int, size(rate.tou_demand_rates)[1] / 12)

    start_index = periods_per_month * (month - 1) + 1
    end_index = periods_per_month * month

    print("start index ", start_index, "\n")
    print("end_index ", end_index, "\n")

    tou_demand = rate.tou_demand_rates[start_index:end_index]

    function is_in_range(item::Integer)
        return item >= t_start && item <= t_end
    end

    tou_rate_sched = []
    i = start_index
    while i <= end_index
        rates_at_time = filter(is_in_range, rate.tou_demand_ratchet_timesteps[i])
        rates_at_time = rates_at_time .- (t_start - 1)
        push!(tou_rate_sched, rates_at_time)
        i += 1
    end

    
    results = Dict("energy_rates" => energy_rates, "monthly_demand_rates" => monthly_demand, 
        "tou_demand_rates" => tou_demand, "tou_demand_timesteps" => tou_rate_sched)

    return results
end

function month_of_hour(time::Integer)

        # returns month number 1..12 given
        #   time: hour index in year 1..8760
        if (time < 0) return 0 end
        if (time < 745) return 1 end
        if (time < 1417) return 2 end
        if (time < 2161) return 3 end
        if (time < 2881) return 4 end
        if (time < 3625) return 5 end
        if (time < 4345) return 6 end
        if (time < 5089) return 7 end
        if (time < 5833) return 8 end
        if (time < 6553) return 9 end
        if (time < 7297) return 10 end
        if (time < 8017) return 11 end
        if (time < 8761) return 12 end
        return 0;
end