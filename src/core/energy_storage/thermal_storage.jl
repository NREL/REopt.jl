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
Cold thermal energy storage sytem; specifically, a chilled water system used to meet thermal cooling loads.

`ColdThermalStorage` is an optional REopt input with the following keys and default values:

```julia
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 56.0 # Warmed-side return water temperature from the cooling load to the ColdTES (top of tank)
    cool_water_temp_degF::Float64 = 44.0 # Chilled-side supply water temperature from ColdTES (bottom of tank) to the cooling load
    internal_efficiency_fraction::Float64 = 0.999999 # Thermal losses due to mixing from thermal power entering or leaving tank
    soc_min_fraction::Float64 = 0.1 # Minimum allowable TES thermal state of charge
    soc_init_fraction::Float64 = 0.5 # TES thermal state of charge at first hour of optimization
    installed_cost_per_gal::Float64 = 1.50 # Thermal energy-based cost of TES (e.g. volume of the tank)
    thermal_decay_rate_fraction::Float64 = 0.0004 # Thermal loss (gain) rate as a fraction of energy storage capacity, per hour (frac*energy_capacity/hr = kw_thermal)
    om_cost_per_gal::Float64 = 0.0 # Yearly fixed O&M cost dependent on storage energy size
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
```
"""
Base.@kwdef struct ColdThermalStorageDefaults <: AbstractThermalStorageDefaults
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 56.0
    cool_water_temp_degF::Float64 = 44.0
    internal_efficiency_fraction::Float64 = 0.999999
    soc_min_fraction::Float64 = 0.1
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
end


"""
`HotThermalStorage` is an optional REopt input with the following keys and default values:

```julia
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 180.0
    cool_water_temp_degF::Float64 = 160.0
    internal_efficiency_fraction::Float64 = 0.999999
    soc_min_fraction::Float64 = 0.1
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
```
"""
Base.@kwdef struct HotThermalStorageDefaults <: AbstractThermalStorageDefaults
    min_gal::Float64 = 0.0
    max_gal::Float64 = 0.0
    hot_water_temp_degF::Float64 = 180.0
    cool_water_temp_degF::Float64 = 160.0
    internal_efficiency_fraction::Float64 = 0.999999
    soc_min_fraction::Float64 = 0.1
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
end



"""
    function ThermalStorage(d::Dict, f::Financial, time_steps_per_hour::Int)

Construct ThermalStorage struct from Dict with keys-val pairs from the 
REopt [Hot,Cold]ThermalStorage and Financial inputs. 
"""
struct ThermalStorage <: AbstractThermalStorage
    min_gal::Float64
    max_gal::Float64
    hot_water_temp_degF::Float64
    cool_water_temp_degF::Float64
    internal_efficiency_fraction::Float64
    soc_min_fraction::Float64
    soc_init_fraction::Float64
    installed_cost_per_gal::Float64
    thermal_decay_rate_fraction::Float64
    om_cost_per_gal::Float64
    macrs_option_years::Int
    macrs_bonus_fraction::Float64
    total_rebate_per_kwh::Float64
    min_kw::Float64
    max_kw::Float64
    min_kwh::Float64
    max_kwh::Float64
    installed_cost_per_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    net_present_cost_per_kwh::Float64
    om_cost_per_kwh::Float64

    function ThermalStorage(s::AbstractThermalStorageDefaults, f::Financial, time_steps_per_hour::Int)
         
        delta_T_degF = s.hot_water_temp_degF - s.cool_water_temp_degF
        avg_rho_kg_per_m3 = 998.2 
        avg_cp_kj_per_kgK = 4.184 #TODO: add CoolProp reference or perform analogous calculations for water and build lookup tables
        kwh_per_gal = convert_gal_to_kwh(delta_T_degF, avg_rho_kg_per_m3, avg_cp_kj_per_kgK)
        min_kwh = s.min_gal * kwh_per_gal
        max_kwh = s.max_gal * kwh_per_gal
        min_kw = min_kwh * time_steps_per_hour
        max_kw = max_kwh * time_steps_per_hour
        om_cost_per_kwh = s.om_cost_per_gal / kwh_per_gal
    
        charge_efficiency = s.internal_efficiency_fraction^0.5
        discharge_efficiency = s.internal_efficiency_fraction^0.5
        installed_cost_per_kwh = s.installed_cost_per_gal / kwh_per_gal
      
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = installed_cost_per_kwh,
            replacement_cost = 0.0,
            replacement_year = 100,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
            macrs_bonus_fraction = s.macrs_bonus_fraction,
            macrs_itc_reduction = s.macrs_itc_reduction
        ) - s.total_rebate_per_kwh
    
        return new(
            s.min_gal,
            s.max_gal,
            s.hot_water_temp_degF,
            s.cool_water_temp_degF,
            s.internal_efficiency_fraction,
            s.soc_min_fraction,
            s.soc_init_fraction,
            s.installed_cost_per_gal,
            s.thermal_decay_rate_fraction,
            s.om_cost_per_gal,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.total_rebate_per_kwh,
            min_kw,
            max_kw,
            min_kwh,
            max_kwh,
            installed_cost_per_kwh,
            charge_efficiency,
            discharge_efficiency,
            net_present_cost_per_kwh,
            om_cost_per_kwh,
        )
    end
end
