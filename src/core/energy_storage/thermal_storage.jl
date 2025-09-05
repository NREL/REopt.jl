# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.


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
    macrs_bonus_fraction::Float64 = 0.6
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
    macrs_bonus_fraction::Float64 = 0.6
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
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
    can_serve_dhw::Bool = true
    can_serve_space_heating:Bool = true
    can_serve_process_heat::Bool = false
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
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
    can_supply_steam_turbine = false
    can_serve_dhw::Bool = true
    can_serve_space_heating::Bool = true
    can_serve_process_heat::Bool = false
    supply_turbine_only::Bool = false
end


"""
`HighTempThermalStorage` is an optional REopt input with the following keys and default values:

```julia
    fluid::String = "INCOMP::Nak"
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 0.0
    hot_temp_degF::Float64 = 1065.0
    cool_temp_degF::Float64 = 554.0
    internal_efficiency_fraction::Float64 = 0.999999
    soc_min_fraction::Float64 = 0.1
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_gal::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_gal::Float64 = 0.0
    macrs_option_years::Int = 7
    macrs_bonus_fraction::Float64 = 0.6
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
    can_supply_steam_turbine::Bool = true
    can_serve_dhw::Bool = false
    can_serve_space_heating:Bool = false
    can_serve_process_heat::Bool = true
    one_direction_flow::Bool = false
```
"""
Base.@kwdef struct HighTempThermalStorageDefaults <: AbstractThermalStorageDefaults
    fluid::String = "INCOMP::NaK"
    min_kwh::Float64 = 0.0
    max_kwh::Float64 = 0.0
    hot_temp_degF::Float64 = 1065.0
    cool_temp_degF::Float64 = 554.0
    internal_efficiency_fraction::Float64 = 0.999999
    soc_min_fraction::Float64 = 0.1
    soc_init_fraction::Float64 = 0.5
    installed_cost_per_kwh::Float64 = 1.50
    thermal_decay_rate_fraction::Float64 = 0.0004
    om_cost_per_kwh::Float64 = 0.0
    macrs_option_years::Int = 5
    macrs_bonus_fraction::Float64 = 1.0
    macrs_itc_reduction::Float64 = 0.5
    total_itc_fraction::Float64 = 0.3
    total_rebate_per_kwh::Float64 = 0.0
    can_supply_steam_turbine::Bool = true
    can_serve_dhw::Bool = false
    can_serve_space_heating::Bool = false
    can_serve_process_heat::Bool = true
    supply_turbine_only::Bool = false
    one_direction_flow::Bool = false
    num_charge_hours::Float64 = 4.0
    num_discharge_hours::Float64 = 10.0
end


"""
function ColdThermalStorage(d::Dict, f::Financial, time_steps_per_hour::Int)

Construct ColdThermalStorage struct from Dict with keys-val pairs from the 
REopt ColdThermalStorage and Financial inputs. 
"""
struct ColdThermalStorage <: AbstractThermalStorage
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

    function ColdThermalStorage(s::AbstractThermalStorageDefaults, f::Financial, time_steps_per_hour::Int)
         
        kwh_per_gal = get_kwh_per_gal(s.hot_water_temp_degF, s.cool_water_temp_degF)
        min_kwh = s.min_gal * kwh_per_gal
        max_kwh = s.max_gal * kwh_per_gal
        min_kw = min_kwh * time_steps_per_hour
        max_kw = max_kwh * time_steps_per_hour
        om_cost_per_kwh = s.om_cost_per_gal / kwh_per_gal
    
        charge_efficiency = s.internal_efficiency_fraction^0.5
        discharge_efficiency = s.internal_efficiency_fraction^0.5
        installed_cost_per_kwh = s.installed_cost_per_gal / kwh_per_gal

        macrs_schedule = [0.0]
        if s.macrs_option_years == 5 || s.macrs_option_years == 7
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year
        elseif !(s.macrs_option_years == 0)
            throw(@error("ColdThermalStorage macrs_option_years must be 0, 5, or 7."))
        end
      
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = installed_cost_per_kwh,
            replacement_cost = 0.0,
            replacement_year = 100,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = macrs_schedule,
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
            om_cost_per_kwh
        )
    end
end


"""
function HotThermalStorage(d::Dict, f::Financial, time_steps_per_hour::Int)

Construct HotThermalStorage struct from Dict with keys-val pairs from the 
REopt HotThermalStorage and Financial inputs. 
"""
struct HotThermalStorage <: AbstractThermalStorage
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
    can_supply_steam_turbine::Bool
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    supply_turbine_only::Bool

    function HotThermalStorage(s::AbstractThermalStorageDefaults, f::Financial, time_steps_per_hour::Int)
         
        kwh_per_gal = get_kwh_per_gal(s.hot_water_temp_degF, s.cool_water_temp_degF)
        min_kwh = s.min_gal * kwh_per_gal
        max_kwh = s.max_gal * kwh_per_gal
        min_kw = min_kwh * time_steps_per_hour
        max_kw = max_kwh * time_steps_per_hour
        om_cost_per_kwh = s.om_cost_per_gal / kwh_per_gal
    
        charge_efficiency = s.internal_efficiency_fraction^0.5
        discharge_efficiency = s.internal_efficiency_fraction^0.5
        installed_cost_per_kwh = s.installed_cost_per_gal / kwh_per_gal

        macrs_schedule = [0.0]
        if s.macrs_option_years == 5 || s.macrs_option_years == 7
            macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year
        elseif !(s.macrs_option_years == 0)
            throw(@error("HotThermalStorage macrs_option_years must be 0, 5, or 7."))
        end        
      
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = installed_cost_per_kwh,
            replacement_cost = 0.0,
            replacement_year = 100,
            discount_rate = f.owner_discount_rate_fraction,
            tax_rate = f.owner_tax_rate_fraction,
            itc = s.total_itc_fraction,
            macrs_schedule = macrs_schedule,
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
            s.can_supply_steam_turbine,
            s.can_serve_dhw,
            s.can_serve_space_heating,
            s.can_serve_process_heat,
            s.supply_turbine_only
        )
    end
end


"""
function HighTempThermalStorage(d::Dict, f::Financial, time_steps_per_hour::Int)

Construct HighTempThermalStorage struct from Dict with keys-val pairs from the 
REopt HighTempThermalStorage and Financial inputs. 
"""
struct HighTempThermalStorage <: AbstractThermalStorage
    fluid::String
    hot_temp_degF::Float64
    cool_temp_degF::Float64
    internal_efficiency_fraction::Float64
    soc_min_fraction::Float64
    soc_init_fraction::Float64
    thermal_decay_rate_fraction::Float64
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
    can_supply_steam_turbine::Bool
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    supply_turbine_only::Bool
    one_direction_flow::Bool
    num_charge_hours::Float64
    num_discharge_hours::Float64

    function HighTempThermalStorage(s::AbstractThermalStorageDefaults, f::Financial, time_steps_per_hour::Int)
        # TODO: develop a storage sizing/costing model using delta-T from hot_temp_degF and cool_temp_degF, as is done in HotThermalStorage 
        min_kw = s.min_kwh / max(s.num_charge_hours, s.num_discharge_hours)
        max_kw = s.max_kwh / min(s.num_charge_hours, s.num_discharge_hours)
    
        charge_efficiency = s.internal_efficiency_fraction^0.5
        discharge_efficiency = s.internal_efficiency_fraction^0.5
      
        net_present_cost_per_kwh = effective_cost(;
            itc_basis = s.installed_cost_per_kwh,
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
            s.fluid,
            s.hot_temp_degF,
            s.cool_temp_degF,
            s.internal_efficiency_fraction,
            s.soc_min_fraction,
            s.soc_init_fraction,
            s.thermal_decay_rate_fraction,
            s.macrs_option_years,
            s.macrs_bonus_fraction,
            s.total_rebate_per_kwh,
            min_kw,
            max_kw,
            s.min_kwh,
            s.max_kwh,
            s.installed_cost_per_kwh,
            charge_efficiency,
            discharge_efficiency,
            net_present_cost_per_kwh,
            s.om_cost_per_kwh,
            s.can_supply_steam_turbine,
            s.can_serve_dhw,
            s.can_serve_space_heating,
            s.can_serve_process_heat,
            s.supply_turbine_only,
            s.one_direction_flow,
            s.num_charge_hours,
            s.num_discharge_hours
        )
    end
end

   
