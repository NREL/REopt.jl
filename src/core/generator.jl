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
    Generator

struct with inner constructor:
```julia
function Generator(;
    existing_kw::Real=0,
    min_kw::Real=0,
    max_kw::Real=1.0e6,
    installed_cost_per_kw::Real=500.0,
    om_cost_per_kw::Real=10.0,
    om_cost_per_kwh::Float64=0.0,
    fuel_cost_per_gallon::Float64 = 3.0,
    fuel_slope_gal_per_kwh::Float64 = 0.076,
    fuel_intercept_gal_per_hr::Float64 = 0.0,
    fuel_avail_gal::Float64 = 660.0,
    min_turn_down_pct::Float64 = 0.0,
    only_runs_during_grid_outage::Bool = true,
    sells_energy_back_to_grid::Bool = false,
    can_net_meter::Bool = false,
    can_wholesale::Bool = false,
    can_export_beyond_nem_limit = false,
    macrs_option_years::Int = 0,
    macrs_bonus_pct::Float64 = 1.0,
    macrs_itc_reduction::Float64 = 0.0,
    federal_itc_pct::Float64 = 0.0,
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
)
```
"""
struct Generator <: AbstractGenerator
    existing_kw
    min_kw
    max_kw
    installed_cost_per_kw
    om_cost_per_kw
    om_cost_per_kwh
    fuel_cost_per_gallon
    fuel_slope_gal_per_kwh
    fuel_intercept_gal_per_hr
    fuel_avail_gal
    min_turn_down_pct
    only_runs_during_grid_outage
    sells_energy_back_to_grid
    can_net_meter
    can_wholesale
    can_export_beyond_nem_limit
    macrs_option_years
    macrs_bonus_pct
    macrs_itc_reduction
    federal_itc_pct
    federal_rebate_per_kw
    state_ibi_pct
    state_ibi_max
    state_rebate_per_kw
    state_rebate_max
    utility_ibi_pct
    utility_ibi_max
    utility_rebate_per_kw
    utility_rebate_max
    production_incentive_per_kwh
    production_incentive_max_benefit
    production_incentive_years
    production_incentive_max_kw

    function Generator(;
        existing_kw::Real=0,
        min_kw::Real=0,
        max_kw::Real=1.0e6,
        installed_cost_per_kw::Real=500.0,
        om_cost_per_kw::Real=10.0,
        om_cost_per_kwh::Float64=0.0,
        fuel_cost_per_gallon::Float64 = 3.0,
        fuel_slope_gal_per_kwh::Float64 = 0.076,
        fuel_intercept_gal_per_hr::Float64 = 0.0,
        fuel_avail_gal::Float64 = 660.0,
        min_turn_down_pct::Float64 = 0.0,
        only_runs_during_grid_outage::Bool = true,
        sells_energy_back_to_grid::Bool = false,
        can_net_meter::Bool = true,
        can_wholesale::Bool = true,
        can_export_beyond_nem_limit = true,
        macrs_option_years::Int = 0,
        macrs_bonus_pct::Float64 = 1.0,
        macrs_itc_reduction::Float64 = 0.0,
        federal_itc_pct::Float64 = 0.0,
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
        )

        new(
            existing_kw,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            om_cost_per_kwh,
            fuel_cost_per_gallon,
            fuel_slope_gal_per_kwh,
            fuel_intercept_gal_per_hr,
            fuel_avail_gal,
            min_turn_down_pct,
            only_runs_during_grid_outage,
            sells_energy_back_to_grid,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
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
            production_incentive_max_kw
        )
    end
end
