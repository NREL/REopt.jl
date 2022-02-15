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
ElectricStorage

Electric storage system (i.e., battery system).

```julia
Base.@kwdef struct ElectricStorage <: AbstractStorage
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end
```
"""
Base.@kwdef struct ElectricStorage <: AbstractStorage
    min_kw::Float64 = 0.0
    max_kw::Float64 = 1.0e4
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 1.0e6
    internal_efficiency_pct::Float64 = 0.975
    inverter_efficiency_pct::Float64 = 0.96
    rectifier_efficiency_pct::Float64 = 0.96
    soc_min_pct::Float64 = 0.2
    soc_init_pct::Float64 = 0.5
    can_grid_charge::Bool = true
    installed_cost_per_kw::Float64 = 840.0
    installed_cost_per_kwh::Float64 = 420.0
    replace_cost_per_kw::Float64 = 410.0
    replace_cost_per_kwh::Float64 = 200.0
    inverter_replacement_year::Int = 10
    battery_replacement_year::Int = 10
    macrs_option_years::Int = 7
    macrs_bonus_pct::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end

struct ElecStorage <: AbstractStorage
    type::Symbol
    min_kw::Float64
    max_kw::Float64
    min_kwh::Float64
    max_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    soc_min_pct::Float64
    soc_init_pct::Float64
    installed_cost_per_kw::Float64
    installed_cost_per_kwh::Float64
    can_grid_charge::Bool
    grid_charge_efficiency::Float64
end


"""
    # function ElecStorage(d::Dict{Symbol,Dict}, f::Financial)

Construct ElecStorage struct from Dict with keys-val pairs from the 
    REopt ElectricStorage and Financial inputs. 
"""
function ElecStorage(d::Dict, f::Financial)  
    if d[:can_grid_charge]
        grid_charge_efficiency = d[:charge_efficiency]
    else
        grid_charge_efficiency = 0.0
    end
    fill_storage_vals!(d, f)

    return ElecStorage(
        "ElectricStorage",
        d[:min_kw],
        d[:max_kw],
        d[:min_kwh],
        d[:max_kwh],
        d[:charge_efficiency],
        d[:discharge_efficiency],
        d[:soc_min_pct],
        d[:soc_init_pct],
        d[:installed_cost_per_kw],
        d[:installed_cost_per_kwh],
        d[:can_grid_charge],
        grid_charge_efficiency
    )
    # TODO expand for smart thermostat
end