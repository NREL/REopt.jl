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

prime_movers = ["recip_engine", "micro_turbine", "combustion_turbine", "fuel_cell"]

"""
`CHP` is an optional REopt input with the following keys and default values:
```julia
    prime_mover::String = ""
    fuel_cost_per_mmbtu::Union{<:Real, AbstractVector{<:Real}} = []  # REQUIRED

    # Required "custom inputs" if not providing prime_mover:
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = NaN
    tech_sizes_for_cost_curve::Union{Float64, AbstractVector{Float64}} = NaN
    om_cost_per_kwh::Float64 = NaN
    electric_efficiency_half_load = NaN
    electric_efficiency_full_load::Float64 = NaN
    min_turn_down_fraction::Float64 = NaN
    thermal_efficiency_full_load::Float64 = NaN
    thermal_efficiency_half_load::Float64 = NaN
    min_allowable_kw::Float64 = NaN
    max_kw::Float64 = NaN
    cooling_thermal_factor::Float64 = NaN  # only needed with cooling load
    unavailability_periods::AbstractVector{Dict} = Dict[]

    # Optional inputs:
    size_class::Int = 1
    min_kw::Float64 = 0.0
    fuel_type::String = "natural_gas" # "restrict_to": ["natural_gas", "landfill_bio_gas", "propane", "diesel_oil"]
    om_cost_per_kw::Float64 = 0.0
    om_cost_per_hr_per_kw_rated::Float64 = 0.0
    supplementary_firing_capital_cost_per_kw::Float64 = 150.0
    supplementary_firing_max_steam_ratio::Float64 = 1.0
    supplementary_firing_efficiency::Float64 = 0.92
    standby_rate_per_kw_per_month::Float64 = 0.0
    reduces_demand_charges::Bool = true
    can_supply_steam_turbine::Bool=false

    macrs_option_years::Int = 5
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    federal_itc_fraction::Float64 = 0.3
    federal_rebate_per_kw::Float64 = 0.0
    state_ibi_fraction::Float64 = 0.0
    state_ibi_max::Float64 = 1.0e10
    state_rebate_per_kw::Float64 = 0.0
    state_rebate_max::Float64 = 1.0e10
    utility_ibi_fraction::Float64 = 0.0
    utility_ibi_max::Float64 = 1.0e10
    utility_rebate_per_kw::Float64 = 0.0
    utility_rebate_max::Float64 = 1.0e10
    production_incentive_per_kwh::Float64 = 0.0
    production_incentive_max_benefit::Float64 = 1.0e9
    production_incentive_years::Int = 0
    production_incentive_max_kw::Float64 = 1.0e9
    can_net_meter::Bool = false
    can_wholesale::Bool = false
    can_export_beyond_nem_limit::Bool = false
    can_curtail::Bool = false
    fuel_renewable_energy_fraction::Float64 = FUEL_DEFAULTS["fuel_renewable_energy_fraction"][fuel_type]
    emissions_factor_lb_CO2_per_mmbtu::Float64 = FUEL_DEFAULTS["emissions_factor_lb_CO2_per_mmbtu"][fuel_type]
    emissions_factor_lb_NOx_per_mmbtu::Float64 = FUEL_DEFAULTS["emissions_factor_lb_NOx_per_mmbtu"][fuel_type]
    emissions_factor_lb_SO2_per_mmbtu::Float64 = FUEL_DEFAULTS["emissions_factor_lb_SO2_per_mmbtu"][fuel_type]
    emissions_factor_lb_PM25_per_mmbtu::Float64 = FUEL_DEFAULTS["emissions_factor_lb_PM25_per_mmbtu"][fuel_type]
```

!!! note "Required inputs"
    To model CHP, you must provide at least `prime_mover` from $(prime_movers) or all of the "custom inputs" defined below.
    If prime_mover is provided, any missing value from the "custom inputs" will be populated from data/chp/chp_default_data.json, 
    based on the prime_mover, boiler_type, and size_class. boiler_type is "steam" if `prime_mover` is "combustion_turbine" 
    and is "hot_water" for all other `prime_mover` types.

    `fuel_cost_per_mmbtu` is always required

"""
Base.@kwdef mutable struct CHP <: AbstractCHP
    prime_mover::String = ""
    fuel_cost_per_mmbtu::Union{<:Real, AbstractVector{<:Real}} = []    
    # following must be provided by user if not providing prime_mover
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = Float64[]
    tech_sizes_for_cost_curve::AbstractVector{Float64} = Float64[]
    om_cost_per_kwh::Float64 = NaN
    electric_efficiency_half_load = NaN
    electric_efficiency_full_load::Float64 = NaN
    min_turn_down_fraction::Float64 = NaN
    thermal_efficiency_full_load::Float64 = NaN
    thermal_efficiency_half_load::Float64 = NaN
    min_allowable_kw::Float64 = NaN
    max_kw::Float64 = NaN
    cooling_thermal_factor::Float64 = NaN  # only needed with cooling load
    unavailability_periods::AbstractVector{Dict} = Dict[]

    # Optional inputs:
    size_class::Int = 1
    min_kw::Float64 = 0.0
    fuel_type::String = "natural_gas" # "restrict_to": ["natural_gas", "landfill_bio_gas", "propane", "diesel_oil"]
    om_cost_per_kw::Float64 = 0.0
    om_cost_per_hr_per_kw_rated::Float64 = 0.0
    supplementary_firing_capital_cost_per_kw::Float64 = 150.0
    supplementary_firing_max_steam_ratio::Float64 = 1.0
    supplementary_firing_efficiency::Float64 = 0.92
    standby_rate_per_kw_per_month::Float64 = 0.0
    reduces_demand_charges::Bool = true
    can_supply_steam_turbine::Bool=false

    macrs_option_years::Int = 5
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    federal_itc_fraction::Float64 = 0.3
    federal_rebate_per_kw::Float64 = 0.0
    state_ibi_fraction::Float64 = 0.0
    state_ibi_max::Float64 = 1.0e10
    state_rebate_per_kw::Float64 = 0.0
    state_rebate_max::Float64 = 1.0e10
    utility_ibi_fraction::Float64 = 0.0
    utility_ibi_max::Float64 = 1.0e10
    utility_rebate_per_kw::Float64 = 0.0
    utility_rebate_max::Float64 = 1.0e10
    production_incentive_per_kwh::Float64 = 0.0
    production_incentive_max_benefit::Float64 = 1.0e9
    production_incentive_years::Int = 0
    production_incentive_max_kw::Float64 = 1.0e9
    can_net_meter::Bool = false
    can_wholesale::Bool = false
    can_export_beyond_nem_limit::Bool = false
    can_curtail::Bool = false
    fuel_renewable_energy_fraction::Real = get(FUEL_DEFAULTS["fuel_renewable_energy_fraction"],fuel_type,0)
    emissions_factor_lb_CO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_CO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_NOx_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_NOx_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_SO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_SO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_PM25_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_PM25_per_mmbtu"],fuel_type,0)
end


function CHP(d::Dict)
    chp = CHP(; dictkeys_tosymbols(d)...)

    @assert chp.fuel_type in FUEL_TYPES

    # Must provide prime_mover or all of custom_chp_inputs
    custom_chp_inputs = Dict{Symbol, Any}(
        :installed_cost_per_kw => chp.installed_cost_per_kw, 
        :tech_sizes_for_cost_curve => chp.tech_sizes_for_cost_curve, 
        :om_cost_per_kwh => chp.om_cost_per_kwh, 
        :electric_efficiency_full_load => chp.electric_efficiency_full_load, 
        :electric_efficiency_half_load => chp.electric_efficiency_half_load, 
        :min_turn_down_fraction => chp.min_turn_down_fraction, 
        :thermal_efficiency_full_load => chp.thermal_efficiency_full_load, 
        :thermal_efficiency_half_load => chp.thermal_efficiency_half_load,
        :min_allowable_kw => chp.min_allowable_kw, 
        :max_kw => chp.max_kw, 
        :cooling_thermal_factor => chp.cooling_thermal_factor
    )

    # Installed cost input validation
    update_installed_cost_params = false
    pass_all_params_error = false
    if !isempty(chp.installed_cost_per_kw) && typeof(chp.installed_cost_per_kw) == Float64
        if !isempty(chp.tech_sizes_for_cost_curve)
            chp.tech_sizes_for_cost_curve = []
            @warn "Ignoring `chp.tech_sizes_for_cost_curve` input because `chp.installed_cost_per_kw` is a scalar"
        end
    elseif !isempty(chp.installed_cost_per_kw) && isempty(chp.tech_sizes_for_cost_curve)
        @error "To model CHP cost curve, you must provide `chp.tech_sizes_for_cost_curve` vector of equal length to `chp.installed_cost_per_kw`"
    elseif isempty(chp.tech_sizes_for_cost_curve)
        update_installed_cost_params = true
    elseif isempty(chp.prime_mover)
        pass_all_params_error = true
    end

    if isempty(chp.prime_mover)
        if !pass_all_params_error
            if any(isnan(v) for v in values(custom_chp_inputs)) || isempty(chp.unavailability_periods)
                pass_all_params_error = true
            end
        end
        if pass_all_params_error
            @error "To model CHP you must provide at least `prime_mover` from $(prime_movers) or all of $([string(k) for k in keys(custom_chp_inputs)]) and unavailability_periods."
        end        
    elseif !(isempty(chp.prime_mover))
        @assert chp.prime_mover in prime_movers
        if chp.prime_mover == "combustion_turbine"
            boiler_type = "steam"
        else
            boiler_type = "hot_water"
        end
        # set all missing default values in custom_chp_inputs
        defaults = get_prime_mover_defaults(chp.prime_mover, boiler_type, chp.size_class)
        for (k, v) in custom_chp_inputs
            if k in [:installed_cost_per_kw, :tech_sizes_for_cost_curve]
                if update_installed_cost_params
                    setproperty!(chp, k, defaults[string(k)])
                end
            elseif isnan(v)
                setproperty!(chp, k, defaults[string(k)])
            end
        end
        if isempty(chp.unavailability_periods)
            chp.unavailability_periods = defaults["unavailability_periods"]
        end
    end

    return chp
end


"""
    get_prime_mover_defaults(prime_mover::String, boiler_type::String, size_class::Int)

return a Dict{String, Union{Float64, AbstractVector{Float64}}} by selecting the appropriate values from 
data/chp/chp_default_data.json, which contains values based on prime_mover, boiler_type, and size_class for the 
custom_chp_inputs, i.e.
- "installed_cost_per_kw"
- "tech_sizes_for_cost_curve"
- "om_cost_per_kwh"
- "electric_efficiency_full_load"
- "min_turn_down_fraction",
- "thermal_efficiency_full_load"
- "thermal_efficiency_half_load"
- "unavailability_periods"
"""
function get_prime_mover_defaults(prime_mover::String, boiler_type::String, size_class::Int)
    pmds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "chp", "chp_defaults.json"))
    prime_mover_defaults = Dict{String, Any}()

    for key in keys(pmds[prime_mover])
        if key in ["thermal_efficiency_full_load", "thermal_efficiency_half_load"]
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