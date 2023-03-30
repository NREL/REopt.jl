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
`Generator` is an optional REopt input with the following keys and default values:
```julia
    existing_kw::Real = 0,
    min_kw::Real = 0,
    max_kw::Real = 1.0e6,
    installed_cost_per_kw::Real = 500.0,
    om_cost_per_kw::Real = off_grid_flag ? 20.0 : 10.0,
    om_cost_per_kwh::Real = 0.0,
    fuel_cost_per_gallon::Real = 3.0,
    electric_efficiency_full_load::Real = 0.3233,
    electric_efficiency_half_load::Real = electric_efficiency_full_load,
    fuel_avail_gal::Real = off_grid_flag ? 1.0e9 : 660.0,
    min_turn_down_fraction::Real = off_grid_flag ? 0.15 : 0.0,
    only_runs_during_grid_outage::Bool = true,
    sells_energy_back_to_grid::Bool = false,
    can_net_meter::Bool = false,
    can_wholesale::Bool = false,
    can_export_beyond_nem_limit = false,
    can_curtail::Bool = false,
    macrs_option_years::Int = 0,
    macrs_bonus_fraction::Real = 0.0,
    macrs_itc_reduction::Real = 0.0,
    federal_itc_fraction::Real = 0.0,
    federal_rebate_per_kw::Real = 0.0,
    state_ibi_fraction::Real = 0.0,
    state_ibi_max::Real = 1.0e10,
    state_rebate_per_kw::Real = 0.0,
    state_rebate_max::Real = 1.0e10,
    utility_ibi_fraction::Real = 0.0,
    utility_ibi_max::Real = 1.0e10,
    utility_rebate_per_kw::Real = 0.0,
    utility_rebate_max::Real = 1.0e10,
    production_incentive_per_kwh::Real = 0.0,
    production_incentive_max_benefit::Real = 1.0e9,
    production_incentive_years::Int = 0,
    production_incentive_max_kw::Real = 1.0e9,
    fuel_renewable_energy_fraction::Real = 0.0,
    emissions_factor_lb_CO2_per_gal::Real = 22.51,
    emissions_factor_lb_NOx_per_gal::Real = 0.0775544,
    emissions_factor_lb_SO2_per_gal::Real = 0.040020476,
    emissions_factor_lb_PM25_per_gal::Real = 0.0,
    replacement_year::Int = off_grid_flag ? 10 : analysis_years, 
    replace_cost_per_kw::Real = off_grid_flag ? installed_cost_per_kw : 0.0
    replace_macrs_option_years::Int = 0,
    replace_macrs_bonus_fraction::Real = 0.0,
    replace_federal_itc_fraction::Real = 0.0,
```

!!! note "Replacement costs" 
    Generator replacement costs will not be considered if `Generator.replacement_year` >= `Financial.analysis_years`.

"""
struct Generator <: AbstractGenerator
    existing_kw
    min_kw
    max_kw
    installed_cost_per_kw
    om_cost_per_kw
    om_cost_per_kwh
    fuel_cost_per_gallon
    electric_efficiency_full_load
    electric_efficiency_half_load
    fuel_avail_gal
    min_turn_down_fraction
    only_runs_during_grid_outage
    sells_energy_back_to_grid
    can_net_meter
    can_wholesale
    can_export_beyond_nem_limit
    can_curtail
    macrs_option_years
    macrs_bonus_fraction
    macrs_itc_reduction
    federal_itc_fraction
    federal_rebate_per_kw
    state_ibi_fraction
    state_ibi_max
    state_rebate_per_kw
    state_rebate_max
    utility_ibi_fraction
    utility_ibi_max
    utility_rebate_per_kw
    utility_rebate_max
    production_incentive_per_kwh
    production_incentive_max_benefit
    production_incentive_years
    production_incentive_max_kw
    fuel_renewable_energy_fraction
    emissions_factor_lb_CO2_per_gal
    emissions_factor_lb_NOx_per_gal
    emissions_factor_lb_SO2_per_gal
    emissions_factor_lb_PM25_per_gal
    replacement_year
    replace_cost_per_kw
    replace_macrs_option_years
    replace_macrs_bonus_fraction
    replace_federal_itc_fraction

    function Generator(;
        off_grid_flag::Bool = false,
        analysis_years::Int = 25, 
        existing_kw::Real = 0,
        min_kw::Real = 0,
        max_kw::Real = 1.0e6,
        installed_cost_per_kw::Real = 500.0,
        om_cost_per_kw::Real= off_grid_flag ? 20.0 : 10.0,
        om_cost_per_kwh::Real = 0.0,
        fuel_cost_per_gallon::Real = 3.0,
        electric_efficiency_full_load::Real = 0.3233,
        electric_efficiency_half_load::Real = electric_efficiency_full_load,
        fuel_avail_gal::Real = off_grid_flag ? 1.0e9 : 660.0,
        min_turn_down_fraction::Real = off_grid_flag ? 0.15 : 0.0,
        only_runs_during_grid_outage::Bool = true,
        sells_energy_back_to_grid::Bool = false,
        can_net_meter::Bool = false,
        can_wholesale::Bool = false,
        can_export_beyond_nem_limit = false,
        can_curtail::Bool = false,
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 1.0,
        macrs_itc_reduction::Real = 0.0,
        federal_itc_fraction::Real = 0.0,
        federal_rebate_per_kw::Real = 0.0,
        state_ibi_fraction::Real = 0.0,
        state_ibi_max::Real = 1.0e10,
        state_rebate_per_kw::Real = 0.0,
        state_rebate_max::Real = 1.0e10,
        utility_ibi_fraction::Real = 0.0,
        utility_ibi_max::Real = 1.0e10,
        utility_rebate_per_kw::Real = 0.0,
        utility_rebate_max::Real = 1.0e10,
        production_incentive_per_kwh::Real = 0.0,
        production_incentive_max_benefit::Real = 1.0e9,
        production_incentive_years::Int = 0,
        production_incentive_max_kw::Real = 1.0e9,
        fuel_renewable_energy_fraction::Real = 0.0,
        emissions_factor_lb_CO2_per_gal::Real = 22.51,
        emissions_factor_lb_NOx_per_gal::Real = 0.0775544,
        emissions_factor_lb_SO2_per_gal::Real = 0.040020476,
        emissions_factor_lb_PM25_per_gal::Real = 0.0,
        replacement_year::Int = off_grid_flag ? 10 : analysis_years, 
        replace_cost_per_kw::Real = off_grid_flag ? installed_cost_per_kw : 0.0,
        replace_macrs_option_years::Int = 0,
        replace_macrs_bonus_fraction::Real = 1.0,
        replace_federal_itc_fraction::Real = 0.0,
    )

        if (replacement_year >= analysis_years) && !(replace_cost_per_kw == 0.0)
            @warn "Generator replacement costs will not be considered because replacement_year >= analysis_years."
        end

        new(
            existing_kw,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            om_cost_per_kwh,
            fuel_cost_per_gallon,
            electric_efficiency_full_load,
            electric_efficiency_half_load,
            fuel_avail_gal,
            min_turn_down_fraction,
            only_runs_during_grid_outage,
            sells_energy_back_to_grid,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail,
            macrs_option_years,
            macrs_bonus_fraction,
            macrs_itc_reduction,
            federal_itc_fraction,
            federal_rebate_per_kw,
            state_ibi_fraction,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_fraction,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw,
            fuel_renewable_energy_fraction,
            emissions_factor_lb_CO2_per_gal,
            emissions_factor_lb_NOx_per_gal,
            emissions_factor_lb_SO2_per_gal,
            emissions_factor_lb_PM25_per_gal,
            replacement_year,
            replace_cost_per_kw,
            replace_macrs_option_years,
            replace_macrs_bonus_fraction,
            replace_federal_itc_fraction
        )
    end
end
