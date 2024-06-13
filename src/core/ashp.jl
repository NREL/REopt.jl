# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

struct ASHP <: AbstractThermalTech
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    can_supply_steam_turbine::Bool
    cop_heating::Array{Float64,1}
    cop_cooling::Array{Float64,1}
    cf_heating::Array{Float64,1}
    cf_cooling::Array{Float64,1}
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    can_serve_cooling::Bool
end


"""
ASHP

If a user provides the `ASHP_SpaceHeater` key then the optimal scenario has the option to purchase 
this new `ASHP` to meet the heating load in addition to using the `ExistingBoiler`
to meet the heating load. 

```julia
function ASHP_SpaceHeater(;
    min_ton::Real = 0.0, # Minimum thermal power size
    max_ton::Real = BIG_NUMBER, # Maximum thermal power size
    installed_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    cop_heating::Array{Float64,1}, # COP of the heating (i.e., thermal produced / electricity consumed)
    cop_cooling::Array{Float64,1}, # COP of the cooling (i.e., thermal produced / electricity consumed)
    cf_heating::Array{Float64,1}, # ASHP's heating capacity factor curves
    cf_cooling::Array{Float64,1}, # ASHP's cooling capacity factor curves
    can_serve_cooling::Union{Bool, Nothing} = nothing # If ASHP can supply heat to the cooling load
)
```
"""
function ASHP_SpaceHeater(;
        min_ton::Real = 0.0,
        max_ton::Real = BIG_NUMBER,
        installed_cost_per_ton::Union{Real, Nothing} = nothing,
        om_cost_per_ton::Union{Real, Nothing} = nothing,
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 0.0,
        cop_heating::Array{Float64,1} = Float64[],
        cop_cooling::Array{Float64,1} = Float64[],
        cf_heating::Array{Float64,1} = Float64[],
        cf_cooling::Array{Float64,1} = Float64[],
        can_serve_cooling::Union{Bool, Nothing} = nothing
    )

    defaults = get_ashp_defaults("SpaceHeating")

    # populate defaults as needed
    if isnothing(installed_cost_per_ton)
        installed_cost_per_ton = defaults["installed_cost_per_ton"]
    end
    if isnothing(om_cost_per_ton)
        om_cost_per_ton = defaults["om_cost_per_ton"]
    end
    if isnothing(can_serve_cooling)
        can_serve_cooling = defaults["can_serve_cooling"]
    end

    #pre-set defaults that aren't mutable due to technology specifications
    can_supply_steam_turbine = defaults["can_supply_steam_turbine"]
    can_serve_space_heating = defaults["can_serve_space_heating"]
    can_serve_dhw = defaults["can_serve_dhw"]
    can_serve_process_heat = defaults["can_serve_process_heat"]
    

    # Convert max sizes, cost factors from mmbtu_per_hour to kw
    min_kw = min_ton * KWH_THERMAL_PER_TONHOUR
    max_kw = max_ton * KWH_THERMAL_PER_TONHOUR

    installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    om_cost_per_kw = om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

    
    ASHP(
        min_kw,
        max_kw,
        installed_cost_per_kw,
        om_cost_per_kw,
        macrs_option_years,
        macrs_bonus_fraction,
        can_supply_steam_turbine,
        cop_heating,
        cop_cooling,
        cf_heating,
        cf_cooling,
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        can_serve_cooling
    )
end


"""
ASHP Water Heater

If a user provides the `ASHP_WaterHeater` key then the optimal scenario has the option to purchase 
this new `ASHP_WaterHeater` to meet the domestic hot water load in addition to using the `ExistingBoiler`
to meet the domestic hot water load. 

```julia
function ASHP_WaterHeater(;
    min_ton::Real = 0.0, # Minimum thermal power size
    max_ton::Real = BIG_NUMBER, # Maximum thermal power size
    installed_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    can_supply_steam_turbine::Union{Bool, nothing} = nothing # If the boiler can supply steam to the steam turbine for electric production
    cop_heating::Array{<:Real,1}, # COP of the heating (i.e., thermal produced / electricity consumed)
)
```
"""
function ASHP_WaterHeater(;
    min_ton::Real = 0.0,
    max_ton::Real = BIG_NUMBER,
    installed_cost_per_ton::Union{Real, Nothing} = nothing,
    om_cost_per_ton::Union{Real, Nothing} = nothing,
    macrs_option_years::Int = 0,
    macrs_bonus_fraction::Real = 0.0,
    cop_heating::Array{Float64,1} = Float64[],
    cf_heating::Array{Float64,1} = Float64[]
    )

    defaults = get_ashp_defaults("DomesticHotWater")

    # populate defaults as needed
    if isnothing(installed_cost_per_ton)
        installed_cost_per_ton = defaults["installed_cost_per_ton"]
    end
    if isnothing(om_cost_per_ton)
        om_cost_per_ton = defaults["om_cost_per_ton"]
    end

     #pre-set defaults that aren't mutable due to technology specifications
     can_supply_steam_turbine = defaults["can_supply_steam_turbine"]
     can_serve_space_heating = defaults["can_serve_space_heating"]
     can_serve_dhw = defaults["can_serve_dhw"]
     can_serve_process_heat = defaults["can_serve_process_heat"]
     can_serve_cooling = defaults["can_serve_cooling"]

    # Convert max sizes, cost factors from mmbtu_per_hour to kw
    min_kw = min_ton * KWH_THERMAL_PER_TONHOUR
    max_kw = max_ton * KWH_THERMAL_PER_TONHOUR

    installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    om_cost_per_kw = om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

    
    ASHP(
        min_kw,
        max_kw,
        installed_cost_per_kw,
        om_cost_per_kw,
        macrs_option_years,
        macrs_bonus_fraction,
        can_supply_steam_turbine,
        cop_heating,
        Float64[],
        cf_heating,
        Float64[],
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        can_serve_cooling
    )
end



"""
function get_ashp_defaults(load_served::String="SpaceHeating")

Obtains defaults for the ASHP from a JSON data file. 

inputs
load_served::String -- identifier of heating load served by AHSP system

returns
ashp_defaults::Dict -- Dictionary containing defaults for ASHP
"""
function get_ashp_defaults(load_served::String="SpaceHeating")
    if !(load_served in ["SpaceHeating", "DomesticHotWater"])
        throw(@error("Invalid inputs: argument `load_served` to function get_ashp_defaults() must be a String in the set ['SpaceHeating', 'DomesticHotWater']."))
    end
    all_ashp_defaults = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "ashp", "ashp_defaults.json"))
    return all_ashp_defaults[load_served]
end