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
`ElectrothermalStorage` is an optional REopt input with the following keys and default values:

```julia
    min_kw::Real = 0.0
    max_kw::Real = 1.0e4
    min_kwh::Real = 0.0
    max_kwh::Real = 1.0e6
    soc_min_fraction::Float64 = 0.2
    soc_init_fraction::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Real = 775.0
    installed_cost_per_kwh::Real = 388.0
    replace_cost_per_kw::Real = 440.0
    replace_cost_per_kwh::Real = 220.0
    om_cost_per_kw::Real=10.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kw::Real = 0.0
    total_rebate_per_kwh::Real = 0.0
    charge_efficiency_fraction::Float64 = 1.0
    thermal_discharge_efficiency_fraction::Float64 = 0.9
    electric_discharge_efficiency_fraction::Float64 = 0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency_fraction : 0.0
    minimum_avg_soc_fraction::Float64 = 0.0
    maximum_thermal_discharge_kwt::Float64 = 1.0e9
```
"""
Base.@kwdef struct ElectrothermalStorageDefaults
    off_grid_flag::Bool = false
    min_kw::Real = 0.0
    max_kw::Real = 1.0e9
    min_kwh::Real = 0.0
    max_kwh::Real = 1.0e9
    soc_min_fraction::Float64 = 0.2
    soc_init_fraction::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Real = 775.0
    installed_cost_per_kwh::Real = 388.0
    replace_cost_per_kw::Real = 440.0
    replace_cost_per_kwh::Real = 220.0
    om_cost_per_kw::Real=10.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kw::Real = 0.0
    total_rebate_per_kwh::Real = 0.0
    charge_efficiency_fraction::Float64 = 1.0
    thermal_discharge_efficiency_fraction::Float64 = 0.9
    electric_discharge_efficiency_fraction::Float64 = 0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency_fraction : 0.0
    minimum_avg_soc_fraction::Float64 = 0.0
    maximum_thermal_discharge_kwt::Real = 1.0e9
end


"""
    function ElectrothermalStorage(d::Dict, f::Financial, settings::Settings)

Construct ElectrothermalStorage struct from Dict with keys-val pairs from the 
REopt ElectrothermalStorage and Financial inputs.
"""
struct ElectrothermalStorage <: AbstractElectrothermalStorage
    min_kw::Real
    max_kw::Real
    min_kwh::Real
    max_kwh::Real
    soc_min_fraction::Float64
    soc_init_fraction::Float64
    can_grid_charge::Bool
    installed_cost_per_kw::Real
    installed_cost_per_kwh::Real
    replace_cost_per_kw::Real
    replace_cost_per_kwh::Real
    om_cost_per_kw::Real
    inverter_replacement_year::Int
    battery_replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_fraction::Float64
    macrs_itc_reduction::Float64
    total_itc_fraction::Float64
    total_rebate_per_kw::Real
    total_rebate_per_kwh::Real
    charge_efficiency_fraction::Float64
    thermal_discharge_efficiency_fraction::Float64
    electric_discharge_efficiency_fraction::Float64
    grid_charge_efficiency::Float64
    net_present_cost_per_kw::Real
    net_present_cost_per_kwh::Real
    minimum_avg_soc_fraction::Float64
    maximum_thermal_discharge_kwt::Real

    function ElectrothermalStorage(d::Dict, f::Financial)  
        s = ElectrothermalStorageDefaults(;d...)
        if s.inverter_replacement_year >= f.analysis_years
            @warn "Battery inverter replacement costs (per_kw) will not be considered because inverter_replacement_year >= analysis_years."
        end

        if s.battery_replacement_year >= f.analysis_years
            @warn "Battery replacement costs (per_kwh) will not be considered because battery_replacement_year >= analysis_years."
        end

        net_present_cost_per_kw = effective_cost(;
            itc_basis = s.installed_cost_per_kw,
            replacement_cost = s.inverter_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kw,
            replacement_year = s.inverter_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction,
            rebate_per_kw = s.total_rebate_per_kw
        )
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
            replacement_cost = s.battery_replacement_year >= f.analysis_years ? 0.0 : s.replace_cost_per_kwh,
            replacement_year = s.battery_replacement_year,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kwh -= s.total_rebate_per_kwh

        return new(
            s.min_kw,
            s.max_kw,
            s.min_kwh,
            s.max_kwh,
            s.soc_min_fraction,
            s.soc_init_fraction,
            s.can_grid_charge,
            s.installed_cost_per_kw,
            s.installed_cost_per_kwh,
            s.replace_cost_per_kw,
            s.replace_cost_per_kwh,
            s.om_cost_per_kw,
            s.inverter_replacement_year,
            s.battery_replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.macrs_itc_reduction,
            s.total_itc_fraction,
            s.total_rebate_per_kw,
            s.total_rebate_per_kwh,
            s.charge_efficiency_fraction,
            s.thermal_discharge_efficiency_fraction,
            s.electric_discharge_efficiency_fraction,
            s.grid_charge_efficiency,
            net_present_cost_per_kw,
            net_present_cost_per_kwh,
            s.minimum_avg_soc_fraction,
            s.maximum_thermal_discharge_kwt
        )
    end
end
