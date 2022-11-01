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

"""
`AbsorptionChiller` is an optional REopt input with the following keys and default values:
```julia
    heat_transfer_medium::Union{String, Nothing} = nothing
    chp_prime_mover::String = ""

    #Required if neither "heat_transfer_medium" nor "chp_prime_mover" included in inputs:
    installed_cost_per_ton::Real
    om_cost_per_ton::Real


    #Optional
    min_ton::Real = 0.0,
    max_ton::Real = 0.0,
    cop_thermal::Real,
    cop_electric::Real = 14.1,
    om_cost_per_ton::Real,
    macrs_option_years::Real = 0,
    macrs_bonus_fraction::Real = 0
```

!!! note "Required inputs"
    To model AbsorptionChiller, you must provide at least one of the following: (i) `heat_transfer_medium` from $(heat_transfer_mediums), (ii) 
    (ii), `chp_prime_mover` from $(chp_prime_movers),or (iii) all of the "custom inputs" defined below.
    If prime_mover is provided, any missing value from the "custom inputs" will be populated from data/absorption_chiller/defaults.json, 
    based on the `heat_transfer_medium` or `prime_mover`. boiler_type is "steam" if `prime_mover` is "combustion_turbine" 
    and is "hot_water" for all other `prime_mover` types.

    `fuel_cost_per_mmbtu` is always required
"""
Base.@kwdef mutable struct AbsorptionChiller <: AbstractThermalTech
    heat_transfer_medium::Union{String, Nothing} = nothing
    installed_cost_per_ton::Union{String, Nothing} = nothing
    min_ton::Real = 0.0
    max_ton::Real = 0.0
    cop_thermal::Union{String, Nothing} = nothing
    cop_electric::Real = 14.1
    om_cost_per_ton::Union{String, Nothing} = nothing
    macrs_option_years::Real = 0
    macrs_bonus_fraction::Real = 0
    min_kw::Real = NaN
    max_kw::Real = NaN
    installed_cost_per_kw::Real = NaN
    om_cost_per_kw::Real = NaN
end

function AbsorptionChiller(d::dict;
        chp_prime_mover::Union{String, Nothing} = nothing,
        existing_boiler::Union{ExistingBoiler, Nothing}=nothing
    )
    #check for 0.0 max size, return nothing if so
    if d["max_ton"] = 0.0
        @warn "0.0 kW provided as capacity for AbsoprtionChiller, this technology will be excluded."
        return nothing
    end

    #check for required inputs (chp_prime_mover or )
    absorp_chl = AbsorptionChiller(; dictkeys_tosymbols(d)...)

    htf_defaults = get_absorption_chiller_defaults(max_ton, heat_transfer_medium, chp_prime_mover)

    absorp_chl.min_kw = absorp_chl.min_ton * KWH_THERMAL_PER_TONHOUR
    absorp_chl.max_kw = absorp_chl.max_ton * KWH_THERMAL_PER_TONHOUR
    absorp_chl.installed_cost_per_kw = absorp_chl.installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    absorp_chl.om_cost_per_kw = absorp_chl.om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

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
    max_ton::Real = 0.0, 
    heat_transfer_medium::Union{String, Nothing} = nothing, 
    chp_prime_mover::Union{String, Nothing} = nothing,
    existing_boiler::Union{ExistingBoiler, Nothing}=nothing
    )
    acds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "absorption_chiller", "absorption_chiller_default_data.json"))
    htf_defaults = Dict{String, Any}()

    if isnothing(heat_transfer_medium)
        if !isnothing(chp_prime_mover)
            if chp_prime_mover == "combustion_engine"
                heat_transfer_medium = "steam"
            else  #if chp_prime mover is blank or is anything but "combustion engine" then assume hot water
                heat_transfer_medium = "hot_water"
            end
        elseif !isnothing(existing_boiler)
            heat_transfer_medium = existing_boiler.production_type
        else
            @error "Invalid argument for `hot_water_or_steam`; must be `hot_water` or `steam`"
        end
    else
        if !(hot_water_or_steam in heat_transfer_mediums)
            @error "Invalid argument for `hot_water_or_steam`; must be `hot_water` or `steam`"
        end
    end

    size_class, frac_higher = get_absorption_chiller_max_size_class(
        d["max_ton"], htf_defaults[heat_transfer_medium]["tech_sizes_for_cost_curve"]
        )

    for key in keys(acds[heat_transfer_medium])
        if key == "cop_thermal"
            htf_defaults[key] = acds[heat_transfer_medium][key]
        elseif key != "tech_sizes_for_cost_curve"
            htf_defaults[key] = (frac_higher * acds[heat_transfer_medium][key][size_class+1] + 
            (1-frac_higher) * acds[heat_transfer_medium][key][size_class])
        end
    end
    acds = nothing  #TODO this is copied from the analogous CHP function.  Do we need?

    response = Dict([
        "hot_water_or_steam": hot_water_or_steam,
        "default_inputs": htf_defaults
    ])

    return htf_defaults
end

"""
get_absorption_chiller_max_size_class(max_tons::Real,sizes_by_class::AbstractVector{Float64})

determines the adjacent size classes of absorption chiller from which to obtain defaults and the fraction of the larger
class to allocate to the default value.

Inputs: 
max_tons::Real -- maximum size of absorption chiller
sizes_by_class::AbstractVector{Float64} -- vector of max sizes by class for the absorption chiller defaults

Returns: 
size_class::Int -- class size index for smaller reference class
ratio::Float -- fraction allocated to larger reference class (i.e., 0=use size_class only; 1=use size_class+1 only)
"""
function get_absorption_chiller_max_size_class(max_tons::Real,sizes_by_class::AbstractVector{Float64})
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
