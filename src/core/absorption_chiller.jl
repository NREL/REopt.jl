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
`AbsorptionChiller` is an optional REopt input with the following keys and default values:
```julia
    thermal_consumption_hot_water_or_steam::Union{String, Nothing} = nothing
    chp_prime_mover::String = ""

    #Required if neither "thermal_consumption_hot_water_or_steam" nor "chp_prime_mover" nor an ExistingBoiler included in inputs:
    installed_cost_per_ton::Union{Float64, Nothing} = nothing
    om_cost_per_ton::Union{Float64, Nothing} = nothing


    #Optional
    min_ton::Float64 = 0.0,
    max_ton::Float64 = BIG_NUMBER,
    cop_thermal::Union{Float64, Nothing} = nothing,
    cop_electric::Float64 = 14.1,
    om_cost_per_ton::Union{Float64, Nothing} = nothing,
    macrs_option_years::Float64 = 0,
    macrs_bonus_fraction::Float64 = 0
```

!!! note "Required inputs"
    To model AbsorptionChiller, you must provide at least one of the following: (i) `thermal_consumption_hot_water_or_steam` from $(HOT_WATER_OR_STEAM), (ii) 
    (ii), `chp_prime_mover` from $(PRIME_MOVERS),or (iii) all of the "custom inputs" defined below.
    If prime_mover is provided, any missing value from the "custom inputs" will be populated from data/absorption_chiller/defaults.json, 
    based on the `thermal_consumption_hot_water_or_steam` or `prime_mover`. boiler_type is "steam" if `prime_mover` is "combustion_turbine" 
    and is "hot_water" for all other `prime_mover` types.
"""
Base.@kwdef mutable struct AbsorptionChiller <: AbstractThermalTech
    thermal_consumption_hot_water_or_steam::Union{String, Nothing} = nothing
    installed_cost_per_ton::Union{Float64, Nothing} = nothing
    min_ton::Float64 = 0.0
    max_ton::Float64 = BIG_NUMBER
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
        existing_boiler::Union{ExistingBoiler, Nothing} = nothing,
        cooling_load::Union{CoolingLoad, Nothing} = nothing
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
        :thermal_consumption_hot_water_or_steam => absorp_chl.thermal_consumption_hot_water_or_steam,
        :installed_cost_per_ton => absorp_chl.installed_cost_per_ton,
        :cop_thermal => absorp_chl.cop_thermal,
        :om_cost_per_ton => absorp_chl.om_cost_per_ton
    )

    if !isnothing(cooling_load)
        load_max_tons = maximum(cooling_load.loads_kw_thermal) / KWH_THERMAL_PER_TONHOUR
    else
        throw(@error "Invalid argument cooling_load=nothing: a CoolingLoad is required for the AbsorptionChiller to be a technology option.")
    end
    if !isnothing(existing_boiler)
        boiler_type = existing_boiler.production_type
    else
        boiler_type = nothing
    end
    htf_defaults_response = get_absorption_chiller_defaults(;
        thermal_consumption_hot_water_or_steam=absorp_chl.thermal_consumption_hot_water_or_steam, 
        chp_prime_mover=chp_prime_mover, 
        boiler_type=boiler_type,
        load_max_tons=load_max_tons
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
    if absorp_chl.max_ton == BIG_NUMBER
        absorp_chl.max_kw = BIG_NUMBER
    else
        absorp_chl.max_kw = absorp_chl.max_ton * KWH_THERMAL_PER_TONHOUR
    end
    absorp_chl.installed_cost_per_kw = absorp_chl.installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    absorp_chl.om_cost_per_kw = absorp_chl.om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

    return absorp_chl
end


"""
get_absorption_chiller_defaults(prime_mover::String, boiler_type::String, size_class::Int)

return a Dict{String, Any} by selecting the appropriate values from 
data/chp/absorption_chiller_defaults.json, which contains values based on heat transfer medium (thermal_consumption_hot_water_or_steam)
such as:
- "installed_cost_per_ton"
- "om_cost_per_ton"
- "cop_thermal"
- "tech_sizes_for_cost_data"

Unlike CHP, the AbsorptionChiller tech sizes inform a single rate for installed_cost_per_ton that uses max_ton as input;
there is no piecewise linear cost curve for the AbsorptionChiller technology.

Inputs: 
thermal_consumption_hot_water_or_steam::Union{String, Nothing} -- identifier of chiller thermal consumption type (steam or hot water)
chp_prime_mover::Union{String, Nothing} -- identifier of CHP prime mover, if any 
boiler_type::Union{String, Nothing} -- identifier of boiler type (steam or hot water)
load_max_tons::Union{Float64, Nothing} -- maximum cooling load [ton]


response keys and descriptions:
"thermal_consumption_hot_water_or_steam" -- string indicator of heat transfer medium for absorption chiller
"default_inputs" -- Dict{string, Float64} containing default values for absorption chiller technology (see above)
"""
function get_absorption_chiller_defaults(;
    thermal_consumption_hot_water_or_steam::Union{String, Nothing} = nothing, 
    chp_prime_mover::Union{String, Nothing} = nothing,
    boiler_type::Union{String, Nothing} = nothing,
    load_max_tons::Union{Float64, Nothing} = nothing
    )
    acds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "absorption_chiller", "absorption_chiller_defaults.json"))
    htf_defaults = Dict{String, Any}()

    # convert Vector{Any} to Vector{Float64}
    for htf in HOT_WATER_OR_STEAM
        for (k, v) in acds[htf]
            if typeof(v) <: AbstractVector{Any}
                acds[htf][k] = convert(Vector{Float64}, v)  # JSON.parsefile makes things Vector{Any}
            end
        end
    end

    #check required inputs
    if isnothing(thermal_consumption_hot_water_or_steam)
        if !isnothing(chp_prime_mover)
            if chp_prime_mover == "combustion_turbine"
                thermal_consumption_hot_water_or_steam = "steam"
            elseif chp_prime_mover in PRIME_MOVERS  #if chp_prime mover is blank or is anything but "combustion_turbine" then assume hot water
                thermal_consumption_hot_water_or_steam = "hot_water"
            else
                throw(@error "Invalid argument for `prime_mover`; must be in $PRIME_MOVERS")
            end
        elseif !isnothing(boiler_type)
            thermal_consumption_hot_water_or_steam = boiler_type
        else
            #default to hot_water if no information given
            thermal_consumption_hot_water_or_steam = "hot_water"
        end
    else
        if !(thermal_consumption_hot_water_or_steam in HOT_WATER_OR_STEAM)
            throw(@error "Invalid argument for `thermal_consumption_hot_water_or_steam`; must be `hot_water` or `steam`")
        end
    end

    htf_defaults["thermal_consumption_hot_water_or_steam"] = thermal_consumption_hot_water_or_steam

    size_class, frac_higher = get_absorption_chiller_max_size_class(
        load_max_tons, acds[thermal_consumption_hot_water_or_steam]["tech_sizes_for_cost_data"]
        )

    for key in keys(acds[thermal_consumption_hot_water_or_steam])
        if key == "cop_thermal"
            htf_defaults[key] = acds[thermal_consumption_hot_water_or_steam][key]
        elseif key != "tech_sizes_for_cost_data"
            htf_defaults[key] = (frac_higher * acds[thermal_consumption_hot_water_or_steam][key][size_class+1] + 
            (1-frac_higher) * acds[thermal_consumption_hot_water_or_steam][key][size_class])
        end
    end
    acds = nothing  #TODO this is copied from the analogous CHP function.  Do we need?

    response = Dict{String, Any}([
        ("thermal_consumption_hot_water_or_steam", thermal_consumption_hot_water_or_steam),
        ("default_inputs", htf_defaults)
    ])

    return response
end

"""
get_absorption_chiller_max_size_class(load_max_tons::Float64,sizes_by_class::AbstractVector{Float64})

determines the adjacent size classes of absorption chiller from which to obtain defaults and the fraction of the larger
class to allocate to the default value.

Inputs: 
load_max_tons::Float64 -- maximum size of absorption chiller
sizes_by_class::AbstractVector{Float64} -- vector of max sizes by class for the absorption chiller defaults

Returns: 
size_class::Int -- class size index for smaller reference class
ratio::Float -- fraction allocated to larger reference class (i.e., 0=use size_class only; 1=use size_class+1 only)
"""
function get_absorption_chiller_max_size_class(load_max_tons::Float64,sizes_by_class::AbstractVector{Float64})
    num_classes = length(sizes_by_class)
    if load_max_tons <= sizes_by_class[1]
        return 1, 0.0
    elseif load_max_tons > sizes_by_class[num_classes]
        return num_classes-1, 1.0
    else
        for size_class in 1:num_classes-1
            if (load_max_tons > sizes_by_class[size_class] &&
                load_max_tons <= sizes_by_class[size_class+1])
                ratio = ((load_max_tons - sizes_by_class[size_class]) /
                    (sizes_by_class[size_class+1] - sizes_by_class[size_class]))
                return size_class, ratio
            end
        end
    end
end
