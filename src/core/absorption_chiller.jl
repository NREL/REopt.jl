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
    heat_transfer_medium::String = ""
    chp_prime_mover::String = ""

    #Required if neither "heat_transfer_medium" nor "chp_prime_mover" included in inputs:
    installed_cost_per_ton::Union{<:Real, AbstractVector{<:Real}} = []
    tech_sizes_for_cost_curve::Union{<:Real, AbstractVector{<:Real}} = []

    #Optional
    min_ton::Real = 0.0,
    max_ton::Real = 0.0,
    cop_thermal::Real,
    cop_electric::Real = 14.1,
    om_cost_per_ton::Real,
    macrs_option_years::Real = 0,
    macrs_bonus_pct::Real = 0
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
    prime_mover::String = ""
    chp_prime_mover::String = ""
    installed_cost_per_ton::Union{<:Real, AbstractVector{<:Real}} = []
    tech_sizes_for_cost_curve::Union{<:Real, AbstractVector{<:Real}} = []
    min_ton::Real
    max_ton::Real
    cop_thermal::Real
    cop_electric::Real
    installed_cost_us_dollars_per_ton::Real
    om_cost_us_dollars_per_ton::Real
    macrs_option_years::Real
    macrs_bonus_pct::Real
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    function AbsorptionChiller(;
        prime_mover::String = "",
        chp_prime_mover::String = "",
        installed_cost_per_ton::Union{<:Real, AbstractVector{<:Real}} = [],
        tech_sizes_for_cost_curve::Union{<:Real, AbstractVector{<:Real}} = [],
        min_ton::Real = 0.0,
        max_ton::Real = 0.0,
        cop_thermal::Real,
        cop_electric::Real = 14.1,
        installed_cost_per_ton::Real,
        om_cost_per_ton::Real,
        macrs_option_years::Real = 0,
        macrs_bonus_pct::Real = 0,
        )

        min_kw = min_ton * KWH_THERMAL_PER_TONHOUR
        max_kw = max_ton * KWH_THERMAL_PER_TONHOUR
        installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
        om_cost_per_kw = om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

        new(
            prime_mover,
            chp_prime_mover,
            installed_cost_per_ton,
            tech_sizes_for_cost_curve,
            min_ton,
            max_ton,
            cop_thermal,
            cop_electric,
            installed_cost_per_ton,
            om_cost_per_ton,
            macrs_option_years,
            macrs_bonus_pct,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw
        )
    end
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
function get_absorption_chiller_defaults(heat_transfer_medium::String, chp_prime_mover::String)
    acds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "absorption_chiller", "defaults.json"))
    htf_defaults = Dict{String, Any}()

    for key in keys(pmds[prime_mover])
        if key in ["thermal_effic_full_load", "thermal_effic_half_load"]
            prime_mover_defaults[key] = pmds[prime_mover][key][boiler_type][size_class]
        elseif key == "unavailability_periods"
            prime_mover_defaults[key] = convert(Vector{Dict}, pmds[prime_mover][key])
        else
            prime_mover_defaults[key] = pmds[prime_mover][key][size_class]
        end
    end
    pmds = nothing

    for (k,v) in prime_mover_defaults
        if typeof(v) <: AbstractVector{Any} && k != "unavailability_periods"
            prime_mover_defaults[k] = convert(Vector{Float64}, v)  # JSON.parsefile makes things Vector{Any}
        end
    end
    return prime_mover_defaults
end