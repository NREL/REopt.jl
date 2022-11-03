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

heat_transfer_mediums = ["steam", "hot_water"]
chp_prime_movers = ["recip_engine", "micro_turbine", "combustion_turbine", "fuel_cell"]

"""
`AbsorptionChiller` is an optional REopt input with the following keys and default values:
```julia
    hot_water_or_steam::Union{String, Nothing} = nothing
    chp_prime_mover::String = ""

    #Required if neither "hot_water_or_steam" nor "chp_prime_mover" included in inputs:
    installed_cost_per_ton::Float64
    om_cost_per_ton::Float64


    #Optional
    min_ton::Float64 = 0.0,
    max_ton::Float64 = 0.0,
    cop_thermal::Float64,
    cop_electric::Float64 = 14.1,
    om_cost_per_ton::Float64,
    macrs_option_years::Float64 = 0,
    macrs_bonus_fraction::Float64 = 0
```

!!! note "Required inputs"
    To model AbsorptionChiller, you must provide at least one of the following: (i) `hot_water_or_steam` from $(heat_transfer_mediums), (ii) 
    (ii), `chp_prime_mover` from $(chp_prime_movers),or (iii) all of the "custom inputs" defined below.
    If prime_mover is provided, any missing value from the "custom inputs" will be populated from data/absorption_chiller/defaults.json, 
    based on the `hot_water_or_steam` or `prime_mover`. boiler_type is "steam" if `prime_mover` is "combustion_turbine" 
    and is "hot_water" for all other `prime_mover` types.

    `fuel_cost_per_mmbtu` is always required
"""
Base.@kwdef mutable struct AbsorptionChiller <: AbstractThermalTech
    hot_water_or_steam::Union{String, Nothing} = nothing
    installed_cost_per_ton::Union{Float64, Nothing} = nothing
    min_ton::Float64 = 0.0
    max_ton::Float64 = 0.0
    cop_thermal::Union{Float64, Nothing} = nothing
    cop_electric::Float64 = 14.1
    om_cost_per_ton::Union{Float64, Nothing} = nothing
    macrs_option_years::Float64 = 0
    macrs_bonus_fraction::Float64 = 0
    min_kw::Float64 = NaN
    max_kw::Float64 = NaN
    installed_cost_per_kw::Float64 = NaN
    om_cost_per_kw::Float64 = NaN
end

function AbsorptionChiller(d::Dict;
        chp_prime_mover::Union{String, Nothing} = nothing,
        existing_boiler::Union{ExistingBoiler, Nothing} = nothing
    )

    # convert Vector{Any} from JSON dictionary to Vector{Float64}
    for (k, v) in d
        if typeof(v) <: AbstractVector{Any}
            d[k] = convert(Vector{Float64}, v)  # JSON.parsefile makes things Vector{Any}
        end
    end

    absorp_chl = AbsorptionChiller(; dictkeys_tosymbols(d)...)

    #check for 0.0 max size, return nothing if so
    if absorp_chl.max_ton == 0.0
        @warn "0.0 kW provided as capacity for AbsoprtionChiller, this technology will be excluded."
        return nothing
    end

    custom_ac_inputs = Dict{Symbol, Any}(
        :hot_water_or_steam => absorp_chl.hot_water_or_steam,
        :installed_cost_per_ton => absorp_chl.installed_cost_per_ton,
        :cop_thermal => absorp_chl.cop_thermal,
        :om_cost_per_ton => absorp_chl.om_cost_per_ton
    )

    htf_defaults_response = get_absorption_chiller_defaults(;max_ton=absorp_chl.max_ton,
        hot_water_or_steam=absorp_chl.hot_water_or_steam, 
        chp_prime_mover=chp_prime_mover, 
        existing_boiler=existing_boiler
    )
    
    #convert defaults for any properties not enetered
    defaults = htf_defaults_response["default_inputs"]
    for (k, v) in custom_ac_inputs
        if isnothing(v)
            setproperty!(absorp_chl, k, defaults[string(k)])
        end
    end

    # generate derived inputs for use in JuMP model
    absorp_chl.min_kw = absorp_chl.min_ton * KWH_THERMAL_PER_TONHOUR
    absorp_chl.max_kw = absorp_chl.max_ton * KWH_THERMAL_PER_TONHOUR
    absorp_chl.installed_cost_per_kw = absorp_chl.installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    absorp_chl.om_cost_per_kw = absorp_chl.om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

    return absorp_chl
end


"""
get_absorption_chiller_defaults(prime_mover::String, boiler_type::String, size_class::Int)

return a Dict{String, Union{Float64, AbstractVector{Float64}}} by selecting the appropriate values from 
data/chp/chp_default_data.json, which contains values based on prime_mover, boiler_type, and size_class for the 
custom_chp_inputs, i.e.
- "installed_cost_per_kw"
- "tech_sizes_for_cost_curve"
- "om_cost_per_kwh"
- "elec_effic_full_load"
- "min_turn_down_pct",
- "thermal_effic_full_load"
- "thermal_effic_half_load"
- "unavailability_periods"
"""
function get_absorption_chiller_defaults(;
    max_ton::Float64 = 0.0, 
    hot_water_or_steam::Union{String, Nothing} = nothing, 
    chp_prime_mover::Union{String, Nothing} = nothing,
    existing_boiler::Union{ExistingBoiler, Nothing}=nothing
    )
    acds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "absorption_chiller", "absorption_chiller_defaults.json"))
    htf_defaults = Dict{String, Any}()

    # convert Vector{Any} to Vector{Float64}
    for htf in heat_transfer_mediums
        for (k, v) in acds[htf]
            if typeof(v) <: AbstractVector{Any}
                acds[htf][k] = convert(Vector{Float64}, v)  # JSON.parsefile makes things Vector{Any}
            end
        end
    end

    #check required inputs
    if isnothing(hot_water_or_steam)
        if !isnothing(chp_prime_mover)
            if chp_prime_mover == "combustion_engine"
                hot_water_or_steam = "steam"
            else  #if chp_prime mover is blank or is anything but "combustion engine" then assume hot water
                hot_water_or_steam = "hot_water"
            end
        elseif !isnothing(existing_boiler)
            hot_water_or_steam = existing_boiler.production_type
        else
            @error "Invalid argument for `hot_water_or_steam`; must be `hot_water` or `steam`"
        end
    else
        if !(hot_water_or_steam in heat_transfer_mediums)
            @error "Invalid argument for `hot_water_or_steam`; must be `hot_water` or `steam`"
        end
    end

    htf_defaults["hot_water_or_steam"] = hot_water_or_steam

    size_class, frac_higher = get_absorption_chiller_max_size_class(
        max_ton, acds[hot_water_or_steam]["tech_sizes_for_cost_curve"]
        )

    for key in keys(acds[hot_water_or_steam])
        if key == "cop_thermal"
            htf_defaults[key] = acds[hot_water_or_steam][key]
        elseif key != "tech_sizes_for_cost_curve"
            htf_defaults[key] = (frac_higher * acds[hot_water_or_steam][key][size_class+1] + 
            (1-frac_higher) * acds[hot_water_or_steam][key][size_class])
        end
    end
    acds = nothing  #TODO this is copied from the analogous CHP function.  Do we need?

    response = Dict{String, Any}([
        ("hot_water_or_steam", hot_water_or_steam),
        ("default_inputs", htf_defaults)
    ])

    return response
end

"""
get_absorption_chiller_max_size_class(max_tons::Float64,sizes_by_class::AbstractVector{Float64})

determines the adjacent size classes of absorption chiller from which to obtain defaults and the fraction of the larger
class to allocate to the default value.

Inputs: 
max_tons::Float64 -- maximum size of absorption chiller
sizes_by_class::AbstractVector{Float64} -- vector of max sizes by class for the absorption chiller defaults

Returns: 
size_class::Int -- class size index for smaller reference class
ratio::Float -- fraction allocated to larger reference class (i.e., 0=use size_class only; 1=use size_class+1 only)
"""
function get_absorption_chiller_max_size_class(max_tons::Float64,sizes_by_class::AbstractVector{Float64})
    num_classes = length(sizes_by_class)
    if max_tons <= sizes_by_class[1]
        return 1, 0.0
    elseif max_tons > sizes_by_class[num_classes]
        return num_classes-1, 1.0
    else
        for size_class in 1:num_classes-1
            if (max_tons > sizes_by_class[size_class] &&
                max_tons <= sizes_by_class[size_class+1])
                ratio = ((max_tons - sizes_by_class[size_class]) /
                    (sizes_by_class[size_class+1] - sizes_by_class[size_class]))
                return size_class, ratio
            end
        end
    end
end
