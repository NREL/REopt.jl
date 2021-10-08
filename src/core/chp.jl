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

struct CHP <: AbstractThermalTech  # useful to create AbstractHeatingTech or AbstractThermalTech?
    prime_mover::String
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}}
    tech_size_for_cost_curve::Union{Float64, AbstractVector{Float64}}
    om_cost_per_kwh::Float64
    elec_effic_half_load::Float64
    elec_effic_full_load::Float64
    min_turn_down_pct::Float64
    thermal_effic_full_load::Float64
    thermal_effic_half_load::Float64
    min_allowable_kw::Float64
    max_kw::Float64
    cooling_thermal_factor::Float64 
    unavailability_periods::AbstractVector{Dict}

    size_class::Int
    min_kw::Float64
    om_cost_per_kw::Float64
    om_cost_per_hr_per_kw_rated::Float64
    supplementary_firing_capital_cost_per_kw::Float64
    supplementary_firing_max_steam_ratio::Float64
    supplementary_firing_efficiency::Float64
    use_default_derate::Bool
    max_derate_factor::Float64
    derate_start_temp_degF::Float64
    derate_slope_pct_per_degF::Float64
    can_supply_steam_turbine::Bool

    macrs_option_years::Int
    macrs_bonus_pct::Float64
    macrs_itc_reduction::Float64
    federal_itc_pct::Float64
    federal_rebate_per_kw::Float64
    state_ibi_pct::Float64
    state_ibi_max::Float64
    state_rebate_per_kw::Float64
    state_rebate_max::Float64
    utility_ibi_pct::Float64
    utility_ibi_max::Float64
    utility_rebate_per_kw::Float64
    utility_rebate_max::Float64
    production_incentive_per_kwh::Float64
    production_incentive_max_benefit::Float64 
    production_incentive_years::Int
    production_incentive_max_kw::Float64 
    can_net_meter::Bool
    can_wholesale::Bool
    can_export_beyond_nem_limit::Bool
    can_curtail::Bool
    # emissions_factor_lb_CO2_per_mmbtu::Float64,
end


function CHP(;
    prime_mover::String = "",
    # following must be provided by user if not providing prime_mover
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = NaN,
    tech_size_for_cost_curve::Union{Float64, AbstractVector{Float64}} = NaN,
    om_cost_per_kwh::Float64 = NaN,
    elec_effic_half_load = NaN,
    elec_effic_full_load::Float64 = NaN,
    min_turn_down_pct::Float64 = NaN,
    thermal_effic_full_load::Float64 = NaN,
    thermal_effic_half_load::Float64 = NaN,
    min_allowable_kw::Float64 = NaN,
    max_kw::Float64 = NaN,
    cooling_thermal_factor::Float64 = NaN,  # only needed with cooling load
    unavailability_periods::AbstractVector{Dict} = Dict[],

    size_class::Int = 1,
    min_kw::Float64 = 0.0,
    om_cost_per_kw::Float64 = 0.0,
    om_cost_per_hr_per_kw_rated::Float64 = 0.0,
    supplementary_firing_capital_cost_per_kw::Float64 = 150.0,
    supplementary_firing_max_steam_ratio::Float64 = 1.0,
    supplementary_firing_efficiency::Float64 = 0.92,
    use_default_derate::Bool = true,
    max_derate_factor::Float64 = 1.0,
    derate_start_temp_degF::Float64 = 0.0,
    derate_slope_pct_per_degF::Float64 = 0.0,
    can_supply_steam_turbine::Bool=false,

    macrs_option_years::Int = 5,
    macrs_bonus_pct::Float64 = 1.0,
    macrs_itc_reduction::Float64 = 0.5,
    federal_itc_pct::Float64 = 0.1,
    federal_rebate_per_kw::Float64 = 0.0,
    state_ibi_pct::Float64 = 0.0,
    state_ibi_max::Float64 = 1.0e10,
    state_rebate_per_kw::Float64 = 0.0,
    state_rebate_max::Float64 = 1.0e10,
    utility_ibi_pct::Float64 = 0.0,
    utility_ibi_max::Float64 = 1.0e10,
    utility_rebate_per_kw::Float64 = 0.0,
    utility_rebate_max::Float64 = 1.0e10,
    production_incentive_per_kwh::Float64 = 0.0,
    production_incentive_max_benefit::Float64 = 1.0e9,
    production_incentive_years::Int = 0,
    production_incentive_max_kw::Float64 = 1.0e9,
    can_net_meter::Bool = false,
    can_wholesale::Bool = false,
    can_export_beyond_nem_limit::Bool = false,
    can_curtail::Bool = false,
    # emissions_factor_lb_CO2_per_mmbtu::Float64,
)
    # Must provide prime_mover or all of custom_chp_inputs
    custom_chp_inputs = Dict{Symbol, Any}(
        :installed_cost_per_kw => installed_cost_per_kw, 
        :tech_size_for_cost_curve => tech_size_for_cost_curve, 
        :om_cost_per_kwh => om_cost_per_kwh, 
        :elec_effic_full_load => elec_effic_full_load, 
        :elec_effic_half_load => elec_effic_half_load, 
        :min_turn_down_pct => min_turn_down_pct, 
        :thermal_effic_full_load => thermal_effic_full_load, 
        :thermal_effic_half_load => thermal_effic_half_load,
        :min_allowable_kw => min_allowable_kw, 
        :max_kw => max_kw, 
        :cooling_thermal_factor => cooling_thermal_factor
    )

    if isempty(prime_mover)
        if any(isnan(v) for v in values(custom_chp_inputs)) || isempty(unavailability_periods)
            @error "To model CHP you must provide at least `prime_mover` from $(prime_movers) or all of $([string(k) for k in keys(custom_chp_inputs)]) and unavailability_periods."
        end
    elseif !(isempty(prime_mover))
        @assert prime_mover in prime_movers
        if prime_mover == "combustion_turbine"
            boiler_type = "steam"
        else
            boiler_type = "hot_water"
        end
        # set all missing default values in custom_chp_inputs
        if any(isnan(v) for v in values(custom_chp_inputs)) || isempty(unavailability_periods)
            defaults = get_prime_mover_defaults(prime_mover, boiler_type, size_class)
            for (k,v) in custom_chp_inputs
                if isnan(v)
                    custom_chp_inputs[k] = defaults[string(k)]
                end
            end
            if isempty(unavailability_periods)
                unavailability_periods = defaults["unavailability_periods"]
            end
        end
    end

    CHP(
        prime_mover,
        custom_chp_inputs[:installed_cost_per_kw],
        custom_chp_inputs[:tech_size_for_cost_curve],
        custom_chp_inputs[:om_cost_per_kwh],
        custom_chp_inputs[:elec_effic_half_load],
        custom_chp_inputs[:elec_effic_full_load],
        custom_chp_inputs[:min_turn_down_pct],
        custom_chp_inputs[:thermal_effic_full_load],
        custom_chp_inputs[:thermal_effic_half_load],
        custom_chp_inputs[:min_allowable_kw],
        custom_chp_inputs[:max_kw],
        custom_chp_inputs[:cooling_thermal_factor], 
        unavailability_periods,
    
        size_class,
        min_kw,
        om_cost_per_kw,
        om_cost_per_hr_per_kw_rated,
        supplementary_firing_capital_cost_per_kw,
        supplementary_firing_max_steam_ratio,
        supplementary_firing_efficiency,
        use_default_derate,
        max_derate_factor,
        derate_start_temp_degF,
        derate_slope_pct_per_degF,
        can_supply_steam_turbine,
    
        macrs_option_years,
        macrs_bonus_pct,
        macrs_itc_reduction,
        federal_itc_pct,
        federal_rebate_per_kw,
        state_ibi_pct,
        state_ibi_max,
        state_rebate_per_kw,
        state_rebate_max,
        utility_ibi_pct,
        utility_ibi_max,
        utility_rebate_per_kw,
        utility_rebate_max,
        production_incentive_per_kwh,
        production_incentive_max_benefit, 
        production_incentive_years,
        production_incentive_max_kw, 
        can_net_meter,
        can_wholesale,
        can_export_beyond_nem_limit,
        can_curtail,
        # emissions_factor_lb_CO2_per_mmbtu
    )
end



# make structs for all the prime movers and just attach the appropriate one to the CHP struct?
# (use the values in API input_files/CHP/chp_default_data.json)
# "thermal_effic_full_load", "thermal_effic_half_load" vary by boiler using hot water or steam
# if not providing prime_mover then must provide:


"""
    get_prime_mover_defaults(prime_mover::String, boiler_type::String, size_class::Int)

return a Dict{String, Union{Float64, AbstractVector{Float64}}} by selecting the appropriate values from 
data/chp/chp_default_data.json, which contains values based on prime_mover, boiler_type, and size_class for the 
custom_chp_inputs, i.e.
- "installed_cost_per_kw"
- "tech_size_for_cost_curve"
- "om_cost_per_kwh"
- "elec_effic_full_load"
- "min_turn_down_pct",
- "thermal_effic_full_load"
- "thermal_effic_half_load"
- "unavailability_periods"
"""
function get_prime_mover_defaults(prime_mover::String, boiler_type::String, size_class::Int)
    pmds = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "chp", "chp_defaults.json"))
    prime_mover_defaults = Dict{String, Any}()

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