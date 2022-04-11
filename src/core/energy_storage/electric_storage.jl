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
    ElectricStorageDefaults

Electric storage system defaults. Overridden by user inputs.

```julia
Base.@kwdef struct ElectricStorageDefaults
    off_grid_flag::Bool = false # TODO: Should this go here in the help text? 
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Float64 = 775.0
    installed_cost_per_kwh::Float64 = 388.0
    replace_cost_per_kw::Float64 = 440.0
    replace_cost_per_kwh::Float64 = 220.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_pct * internal_efficiency_pct^0.5
    discharge_efficiency::Float64 = inverter_efficiency_pct * internal_efficiency_pct^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
end
```
"""
Base.@kwdef struct ElectricStorageDefaults
    off_grid_flag::Bool = false
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = off_grid_flag ? 1.0 : 0.5
    can_grid_charge::Bool = off_grid_flag ? false : true
    installed_cost_per_kw::Float64 = 775.0
    installed_cost_per_kwh::Float64 = 388.0
    replace_cost_per_kw::Float64 = 440.0
    replace_cost_per_kwh::Float64 = 220.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
    charge_efficiency::Float64 = rectifier_efficiency_pct * internal_efficiency_pct^0.5
    discharge_efficiency::Float64 = inverter_efficiency_pct * internal_efficiency_pct^0.5
    grid_charge_efficiency::Float64 = can_grid_charge ? charge_efficiency : 0.0
end


"""
    function ElectricStorage(d::Dict, f::Financial, settings::Settings)

Construct ElectricStorage struct from Dict with keys-val pairs from the 
REopt ElectricStorage and Financial inputs.
"""
struct ElectricStorage <: AbstractElectricStorage
    min_kw::Float64
    max_kw::Float64
    min_kwh::Float64
    max_kwh::Float64
    internal_efficiency_pct::Float64
    inverter_efficiency_pct::Float64
    rectifier_efficiency_pct::Float64
    soc_min_pct::Float64
    soc_init_pct::Float64
    can_grid_charge::Bool
    installed_cost_per_kw::Float64
    installed_cost_per_kwh::Float64
    replace_cost_per_kw::Float64
    replace_cost_per_kwh::Float64
    inverter_replacement_year::Int
    battery_replacement_year::Int
    macrs_option_years::Int
    macrs_bonus_pct::Float64
    macrs_itc_reduction::Float64
    total_itc_pct::Float64
    total_rebate_per_kw::Float64
    total_rebate_per_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    grid_charge_efficiency::Float64
    net_present_cost_per_kw::Float64
    net_present_cost_per_kwh::Float64

    function ElectricStorage(d::Dict, f::Financial)  
        s = ElectricStorageDefaults(;d...)

        if s.inverter_replacement_year >= f.analysis_years
            s.replace_cost_per_kw = 0.0
            @warn "Assuming electric storage replace_cost_per_kw = 0.0 because inverter_replacement_year >= analysis_years."
        end

        if s.battery_replacement_year >= f.analysis_years
            s.replace_cost_per_kwh = 0.0
            @warn "Assuming electric storage replace_cost_per_kwh = 0.0 because battery_replacement_year >= analysis_years."
        end

        
        net_present_cost_per_kw = effective_cost(;
            itc_basis = s.installed_cost_per_kw,
            replacement_cost = s.replace_cost_per_kw,
            replacement_year = s.inverter_replacement_year,
            discount_rate = f.owner_discount_pct,
            tax_rate = f.owner_tax_pct,
            itc = s.total_itc_pct,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_pct = s.macrs_bonus_pct,
            macrs_itc_reduction = s.macrs_itc_reduction,
            rebate_per_kw = s.total_rebate_per_kw
        )
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
            replacement_cost = s.replace_cost_per_kwh,
            replacement_year = s.battery_replacement_year,
            discount_rate = f.owner_discount_pct,
            tax_rate = f.owner_tax_pct,
            itc = s.total_itc_pct,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_pct = s.macrs_bonus_pct,
            macrs_itc_reduction = s.macrs_itc_reduction
        )

        net_present_cost_per_kwh -= s.total_rebate_per_kwh
    
        return new(
            s.min_kw,
            s.max_kw,
            s.min_kwh,
            s.max_kwh,
            s.internal_efficiency_pct,
            s.inverter_efficiency_pct,
            s.rectifier_efficiency_pct,
            s.soc_min_pct,
            s.soc_init_pct,
            s.can_grid_charge,
            s.installed_cost_per_kw,
            s.installed_cost_per_kwh,
            s.replace_cost_per_kw,
            s.replace_cost_per_kwh,
            s.inverter_replacement_year,
            s.battery_replacement_year,
            s.macrs_option_years,
            s.macrs_bonus_pct,
            s.macrs_itc_reduction,
            s.total_itc_pct,
            s.total_rebate_per_kw,
            s.total_rebate_per_kwh,
            s.charge_efficiency,
            s.discharge_efficiency,
            s.grid_charge_efficiency,
            net_present_cost_per_kw,
            net_present_cost_per_kwh,
        )
    end
end
