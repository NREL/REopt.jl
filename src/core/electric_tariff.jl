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
data for electric tariff in reopt model
    can be defined using custom rates or URDB rate
"""
# TODO function for creating BAU inputs: don't need for tariff b/c Tech repeats no longer needed?
struct ElectricTariff
    energy_rates::Array{Float64,1} 

    monthly_demand_rates::Array{Float64,1}
    time_steps_monthly::Array{Array{Int64,1},1}  # length = 0 or 12

    tou_demand_rates::Array{Float64,1}
    tou_demand_ratchet_timesteps::Array{Array{Int64,1},1}  # length = n_tou_demand_ratchets

    fixed_monthly_charge::Float64
    annual_min_charge::Float64
    min_monthly_charge::Float64

    export_rates::DenseAxisArray{Array{Float64,1}}
    export_bins::Array{Symbol,1}
end


"""
    ElectricTariff

    function ElectricTariff(;
        urdb_label::String="",
        urdb_response::Dict=Dict(),
        year::Int=2020,
        time_steps_per_hour::Int=1,
        NEM::Bool=false,
        wholesale_rate::T=nothing, 
        monthly_energy_rates::Array=[],
        monthly_demand_rates::Array=[],
    ) where {T <: Union{Nothing, Int, Float64, Array}, S <: Union{Nothing, Int, Float64, Array}}
    
"""
function ElectricTariff(;
    urdb_label::String="",
    urdb_response::Dict=Dict(),
    year::Int=2020,
    time_steps_per_hour::Int=1,
    NEM::Bool=false,
    wholesale_rate::T=nothing, 
    monthly_energy_rates::Array=[],
    monthly_demand_rates::Array=[],
    ) where {T <: Union{Nothing, Int, Float64, Array}, S <: Union{Nothing, Int, Float64, Array}}
    
    nem_rate = [100.0 for _ in 1:8760*time_steps_per_hour]

    u = nothing
    if !isempty(urdb_label)

        u = URDBrate(urdb_label, year, time_steps_per_hour=time_steps_per_hour)

    elseif !isempty(urdb_response)

        u = URDBrate(urdb_response, year, time_steps_per_hour=time_steps_per_hour)

    elseif !isempty(monthly_energy_rates) && !isempty(monthly_demand_rates)

        invalid_args = String[]
        if !(length(monthly_energy_rates) == 12)
            push!(invalid_args, "length(monthly_energy_rates) must equal, got length $(length(monthly_energy_rates))")
        end
        if !(length(monthly_demand_rates) == 12)
            push!(invalid_args, "length(monthly_demand_rates) must equal, got length $(length(monthly_demand_rates))")
        end
        if length(invalid_args) > 0
            error("Invalid argument values: $(invalid_args)")
        end

        tou_demand_rates = Float64[]
        tou_demand_ratchet_timesteps = []
        demand_rates_monthly = monthly_demand_rates
        time_steps_monthly = get_monthly_timesteps(year, time_steps_per_hour=time_steps_per_hour)
        energy_rates = Real[]
        for m in 1:12
            append!(energy_rates, [monthly_energy_rates[m] for ts in time_steps_monthly[m]])
        end

        fixed_monthly_charge = 0.0
        annual_min_charge = 0.0
        min_monthly_charge = 0.0

        if NEM
            nem_rate = [-0.999 * x for x in energy_rates]
        end
    else
        error("Creating ElectricTariff requires at least urdb_label or monthly rates.")
    end

    if !isnothing(u)

        if NEM
            t = get_tier_with_lowest_energy_rate(u)
            nem_rate = [-0.999 * x for x in u.energy_rates[t,:]]
        end

        energy_rates, monthly_demand_rates, tou_demand_rates = remove_tiers_from_urdb_rate(u)
        time_steps_monthly = Array[]
        if !isempty(u.monthly_demand_rates)
            time_steps_monthly = 
                get_monthly_timesteps(year, time_steps_per_hour=time_steps_per_hour)
        end

        tou_demand_ratchet_timesteps = u.tou_demand_ratchet_timesteps
        fixed_monthly_charge = u.fixed_monthly_charge
        annual_min_charge = u.annual_min_charge
        min_monthly_charge = u.min_monthly_charge
    end

    #= export_rates
    3 "tiers": 1. NEM (Net Energy Metering), 2. WHL (Wholesale), 3. CUR (Curtail)
    - if NEM then set ExportRate[:Nem, :] to energy_rate[tier_with_lowest_energy_rate, :]
        - otherwise set to 100 dollars/kWh
    - user can provide either scalar wholesale rate or vector of timesteps, 
        - otherwise set to 100 dollars/kWh
    - curtail cost set to zero by default, but can be specified same as wholesale rate
    =#
    whl_rate = create_export_rate(wholesale_rate, length(energy_rates), time_steps_per_hour)
    
    if !NEM & (sum(whl_rate) >= 0)
        export_rates = DenseAxisArray{Array{Float64,1}}(undef, [])
        export_bins = Symbol[]
    elseif !NEM
        export_bins = [:WHL]
        export_rates = DenseAxisArray([whl_rate], export_bins)
    elseif (sum(whl_rate) >= 0)
        export_bins = [:NEM]
        export_rates = DenseAxisArray([nem_rate], export_bins)
    else
        export_bins = [:NEM, :WHL]  # TODO add :EXC to align with REopt Lite API
        export_rates = DenseAxisArray([nem_rate, whl_rate], export_bins)
    end

    ElectricTariff(
        energy_rates,
        monthly_demand_rates,
        time_steps_monthly,
        tou_demand_rates,
        tou_demand_ratchet_timesteps,
        fixed_monthly_charge,
        annual_min_charge,
        min_monthly_charge,
        export_rates,
        export_bins
    )
end


function get_tier_with_lowest_energy_rate(u::URDBrate)
    """
    ExportRate should be lowest energy cost for tiered rates. 
    Otherwise, ExportRate can be > FuelRate, which leads REopt to export all PV energy produced.
    """
    tier_with_lowest_energy_cost = 1
    if length(u.energy_tier_limits) > 1
        annual_energy_charge_sums = Float64[]
        for etier in u.energy_rates
            push!(annual_energy_charge_sums, sum(etier))
        end
        tier_with_lowest_energy_cost = 
            findall(annual_energy_charge_sums .== minimum(annual_energy_charge_sums))[1]
    end
    return tier_with_lowest_energy_cost
end

# TODO: dispatch custom rates based on options: TOU, monthly, etc.
function CustomRate(flat_energy::Real, flat_demand::Real=0) end


"""
    function create_export_rate(e::Nothing, N::Int, ts_per_hour::Int=1)
No export rate provided by user: set to 100 dollars/kWh for all time
"""
function create_export_rate(e::Nothing, N::Int, ts_per_hour::Int=1)
    [100 for _ in range(1, stop=N) for ts in 1:ts_per_hour]
end


"""
    function create_export_rate(e::T, N::Int, ts_per_hour::Int=1) where T<:Real
Case for scaler export rate provided -> convert to array of timesteps
"""
function create_export_rate(e::T, N::Int, ts_per_hour::Int=1) where T<:Real
    [float(-1*e) for ts in range(1, stop=N) for ts_per_hour::Int=1]
end


"""
    function create_export_rate(e::Array{<:Real, 1}, N::Int, ts_per_hour::Int=1)

Check length of e and upsample if length(e) != N
"""
function create_export_rate(e::Array{<:Real, 1}, N::Int, ts_per_hour::Int=1)
    Ne = length(e)
    if Ne != Int(N/ts_per_hour) || Ne != N
        @error "Export rates do not have correct number of entries. Must be $(N) or $(Int(N/ts_per_hour))."
    end
    if Ne != N  # upsample
        export_rates = [-1*x for x in e for ts in 1:ts_per_hour]
    else
        export_rates = -1*e
    end
    return export_rates
end


"""
    get_monthly_timesteps(year::Int; time_steps_per_hour=1)

return Array{Array{Int64,1},1}, size = (12,)
"""
function get_monthly_timesteps(year::Int; time_steps_per_hour=1)
    a = Array[]
    i = 1
    for m in range(1, stop=12)
        n_days = daysinmonth(Date(string(year) * "-" * string(m)))
        stop = n_days * 24 * time_steps_per_hour + i - 1
        if m == 2 && isleapyear(year)
            stop -= 24 * time_steps_per_hour  # TODO support extra day in leap years?
        end
        steps = [step for step in range(i, stop=stop)]
        append!(a, [steps])
        i = stop + 1
    end
    return a
end

# TODO use this function only for URDBrate
function remove_tiers_from_urdb_rate(u::URDBrate)
    # tariff args: have to validate that there are no tiers
    if length(u.energy_tier_limits) > 1
        @warn "Energy rate contains tiers. Using the first tier!"
    end
    elec_rates = vec(u.energy_rates[1,:])

    if u.n_monthly_demand_tiers > 1
        @warn "Monthly demand rate contains tiers. Using the last tier!"
    end
    if u.n_monthly_demand_tiers > 0
        demand_rates_monthly = vec(u.monthly_demand_rates[:,u.n_monthly_demand_tiers])
    else
        demand_rates_monthly = vec(u.monthly_demand_rates)  # 0×0 Array{Float64,2}
    end

    if u.n_tou_demand_tiers > 1
        @warn "TOU demand rate contains tiers. Using the last tier!"
    end
    if u.n_tou_demand_tiers > 0
        demand_rates = vec(u.tou_demand_rates[:,u.n_tou_demand_tiers])
    else
        demand_rates = vec(u.tou_demand_rates)
    end

    return elec_rates, demand_rates_monthly, demand_rates
end