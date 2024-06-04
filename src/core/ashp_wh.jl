# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

struct ASHP_WH <: AbstractThermalTech
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
ASHP Water Heater

If a user provides the `ASHP_WH` key then the optimal scenario has the option to purchase 
this new `ASHP_WH` to meet the domestic hot water load in addition to using the `ExistingBoiler`
to meet the domestic hot water load. 

```julia
function ASHP_WH(;
    min_ton::Real = 0.0, # Minimum thermal power size
    max_ton::Real = BIG_NUMBER, # Maximum thermal power size
    installed_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    can_supply_steam_turbine::Union{Bool, nothing} = nothing # If the boiler can supply steam to the steam turbine for electric production
    cop_heating::Array{<:Real,2}, # COP of the heating (i.e., thermal produced / electricity consumed)
    can_serve_dhw::Union{Bool, Nothing} = nothing # If ASHP_WH can supply heat to the domestic hot water load
    can_serve_space_heating::Union{Bool, Nothing} = nothing # If ASHP_WH can supply heat to the space heating load
    can_serve_process_heat::Union{Bool, Nothing} = nothing # If ASHP_WH can supply heat to the process heating load
    can_serve_cooling::Union{Bool, Nothing} = nothing # If ASHP_WH can supply heat to the cooling load
)
```
"""
function ASHP_WH(;
    min_ton::Real = 0.0,
    max_ton::Real = BIG_NUMBER,
    installed_cost_per_ton::Union{Real, Nothing} = nothing,
    om_cost_per_ton::Union{Real, Nothing} = nothing,
    macrs_option_years::Int = 0,
    macrs_bonus_fraction::Real = 0.0,
    can_supply_steam_turbine::Union{Bool, Nothing} = nothing,
    cop_heating::Array{Float64,1} = Float64[],
    cop_cooling::Array{Float64,1} = Float64[],
    cf_heating::Array{Float64,1} = Float64[],
    cf_cooling::Array{Float64,1} = Float64[],
    can_serve_dhw::Union{Bool, Nothing} = nothing,
    can_serve_space_heating::Union{Bool, Nothing} = nothing,
    can_serve_process_heat::Union{Bool, Nothing} = nothing,
    can_serve_cooling::Union{Bool, Nothing} = nothing
    )

    defaults = get_ashp_wh_defaults()

    # populate defaults as needed
    if isnothing(installed_cost_per_ton)
        installed_cost_per_ton = defaults["installed_cost_per_ton"]
    end
    if isnothing(om_cost_per_ton)
        om_cost_per_ton = defaults["om_cost_per_ton"]
    end
    if isnothing(can_supply_steam_turbine)
        can_supply_steam_turbine = defaults["can_supply_steam_turbine"]
    end
    if isnothing(can_serve_dhw)
        can_serve_dhw = defaults["can_serve_dhw"]
    end
    if isnothing(can_serve_space_heating)
        can_serve_space_heating = defaults["can_serve_space_heating"]
    end
    if isnothing(can_serve_process_heat)
        can_serve_process_heat = defaults["can_serve_process_heat"]
    end
    if isnothing(can_serve_cooling)
        can_serve_cooling = defaults["can_serve_cooling"]
    end

    # Convert max sizes, cost factors from mmbtu_per_hour to kw
    min_kw = min_ton * KWH_THERMAL_PER_TONHOUR
    max_kw = max_ton * KWH_THERMAL_PER_TONHOUR

    installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
    om_cost_per_kw = om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

    
    ASHP_WH(
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
function get_ashp_wh_defaults()

Obtains defaults for the ASHP_WH from a JSON data file. 

inputs
None

returns
ashp_wh_defaults::Dict -- Dictionary containing defaults for ASHP_WH
"""
function get_ashp_wh_defaults()
    ashp_wh_defaults = JSON.parsefile(joinpath(dirname(@__FILE__), "..", "..", "data", "ashp", "ashp_wh_defaults.json"))
    return ashp_wh_defaults
end