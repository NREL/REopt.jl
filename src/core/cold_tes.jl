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
    ColdStorage

    Cold thermal energy storage sytem; specifically, a chilled water system used to 
    meet thermal cooling loads.

```julia
Base.@kwdef struct ColdThermalStorage <: AbstractStorage
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 56.0
    cool_water_temp_degF::Float64 = 44.0
    internal_efficiency_pct::Float64 = 0.999999
    soc_min_pct::Float64 = 0.1
    soc_init_pct::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 0
    macrs_bonus_pct::Float64 = 0.0
    macrs_itc_reduction::Float64 = 0.0
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end
```
"""
Base.@kwdef struct ColdStorage <: AbstractStorage
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 56.0
    cool_water_temp_degF::Float64 = 44.0
    internal_efficiency_pct::Float64 = 0.999999
    soc_min_pct::Float64 = 0.1
    soc_init_pct::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 0
    macrs_bonus_pct::Float64 = 0.0
    macrs_itc_reduction::Float64 = 0.0
    total_itc_pct::Float64 = 0.0
    total_rebate_per_kw::Float64 = 0.0
    total_rebate_per_kwh::Float64 = 0.0
end


struct ColdThermalStorage <: AbstractStorage
    type::String
    raw_inputs::Dict{String,AbstractStorage}
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
    thermal_decay_rate_fraction::Float64
    om_cost_per_kwh::Float64
end




"""
    # function ColdThermalStorage(d::Dict{Symbol,Dict}, f::Financial)

    Construct ColdThermalStorage struct from Dict with keys-val pairs from the 
    REopt ColdStorage and Financial inputs. 
"""
function ColdThermalStorage(d::Dict, f::Financial)  
    
    s = eval(Meta.parse("ColdStorage" * "(;$d...)"))
    raw_inputs = Dict("ColdThermalStorage" => s)

    delta_T_degF = s.hot_water_temp_degF - s.cool_water_temp_degF
    avg_cp_kj_per_kgK = 998.2 
    avg_rho_kg_per_m3 = 4.184 #TODO: add CoolProp reference or perform analogous calculations for water and build lookup tables
    kwh_per_gal = convert_gal_to_kwh(delta_T_degF, avg_rho_kg_per_m3, avg_cp_kj_per_kgK)
    d[:min_kw] = 0.0
    d[:max_kw] = 1.0e9
    d[:min_kwh] = s.min_gal * kwh_per_gal
    d[:max_kwh] = s.max_gal * kwh_per_gal
    d[:om_cost_per_kwh] = s.om_cost_per_gal * kwh_per_gal
    d[:kwh_per_gal] = kwh_per_gal

    fill_storage_vals!(d, f)

    return ColdThermalStorage(
        "ColdThermalStorage",
        raw_inputs,
        d[:min_kw],
        d[:max_kw],
        d[:min_kwh],
        d[:max_kwh],
        d[:charge_efficiency],
        d[:discharge_efficiency],
        s.soc_min_pct,
        s.soc_init_pct,
        d[:installed_cost_per_kw],
        d[:installed_cost_per_kwh],
        s.thermal_decay_rate_fraction,
        d[:om_cost_per_kwh]
    )
    # TODO expand for smart thermostat
end