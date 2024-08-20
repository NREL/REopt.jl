# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
ASHP_SpaceHeater

If a user provides the `ASHP_SpaceHeater` key then the optimal scenario has the option to purchase 
this new `ASHP` to meet the heating load in addition to using the `ExistingBoiler`
to meet the heating load. 

ASHP_SpaceHeater has the following attributes: 
```julia
    min_kw::Real = 0.0, # Minimum thermal power size
    max_kw::Real = BIG_NUMBER, # Maximum thermal power size
    min_allowable_kw::Real = 0.0 # Minimum nonzero thermal power size if included
    installed_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    heating_cop::Array{Float64,1}, # COP of the heating (i.e., thermal produced / electricity consumed)
    cooling_cop::Array{Float64,1}, # COP of the cooling (i.e., thermal produced / electricity consumed)
    heating_cf::Array{Float64,1}, # ASHP's heating capacity factor curves
    cooling_cf::Array{Float64,1}, # ASHP's cooling capacity factor curves
    can_serve_cooling::Union{Bool, Nothing} = nothing # If ASHP can supply heat to the cooling load
    force_into_system::Union{Bool, Nothing} = nothing # force into system to serve all space heating loads if true
    back_up_temp_threshold_degF::Real = 10 # Degree in F that system switches from ASHP to resistive heater 
```
"""
struct ASHP <: AbstractThermalTech
    min_kw::Real
    max_kw::Real
    min_allowable_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    can_supply_steam_turbine::Bool
    heating_cop::Array{Float64,1}
    cooling_cop::Array{Float64,1}
    heating_cf::Array{Float64,1}
    cooling_cf::Array{Float64,1}
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    can_serve_cooling::Bool
    force_into_system::Bool
    back_up_temp_threshold_degF::Real
    avoided_capex_by_ashp_present_value::Real
end


"""
ASHP_SpaceHeater

If a user provides the `ASHP_SpaceHeater` key then the optimal scenario has the option to purchase 
this new `ASHP` to meet the heating load in addition to using the `ExistingBoiler`
to meet the heating load. 

```julia
function ASHP_SpaceHeater(;
    min_ton::Real = 0.0, # Minimum thermal power size
    max_ton::Real = BIG_NUMBER, # Maximum thermal power size
    min_allowable_ton::Real = 0.0 # Minimum nonzero thermal power size if included
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    can_serve_cooling::Union{Bool, Nothing} = nothing # If ASHP can supply heat to the cooling load
    force_into_system::Union{Bool, Nothing} = nothing # force into system to serve all space heating loads if true
    avoided_capex_by_ashp_present_value::Real = 0.0

    #The following inputs are used to create the attributes heating_cop and heating cf: 
    heating_cop_reference::Array{Float64,1}, # COP of the heating (i.e., thermal produced / electricity consumed)
    heating_cf_reference::Array{Float64,1}, # ASHP's heating capacity factor curves
    heating_reference_temps ::Array{Float64,1}, # ASHP's reference temperatures for heating COP and CF
    back_up_temp_threshold_degF::Real = 10, # Degree in F that system switches from ASHP to resistive heater
    
    #The following inputs are used to create the attributes heating_cop and heating cf: 
    cooling_cop::Array{Float64,1}, # COP of the cooling (i.e., thermal produced / electricity consumed)
    cooling_cf::Array{Float64,1}, # ASHP's cooling capacity factor curves
    heating_reference_temps ::Array{Float64,1}, # ASHP's reference temperatures for cooling COP and CF
    
    #The following input is taken from the Site object:
    ambient_temp_degF::Array{Float64,1}  #time series of ambient temperature
    heating_load::Array{Float64,1} # time series of site space heating load
    cooling_load::Union{Array{Float64,1}, Nothing} # time series of site cooling load
)
```
"""
function ASHP_SpaceHeater(;
        min_ton::Real = 0.0,
        max_ton::Real = BIG_NUMBER,
        min_allowable_ton::Union{Real, Nothing} = nothing,
        installed_cost_per_ton::Union{Real, Nothing} = nothing,
        om_cost_per_ton::Union{Real, Nothing} = nothing,
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 0.0,
        avoided_capex_by_ashp_present_value::Real = 0.0,
        can_serve_cooling::Union{Bool, Nothing} = nothing,
        force_into_system::Union{Bool, Nothing} = nothing,
        heating_cop_reference::Array{Float64,1} = Float64[],
        heating_cf_reference::Array{Float64,1} = Float64[],
        heating_reference_temps::Array{Float64,1} = Float64[],
        back_up_temp_threshold_degF::Union{Real, Nothing} = nothing,
        cooling_cop_reference::Array{Float64,1} = Float64[],
        cooling_cf_reference::Array{Float64,1} = Float64[],
        cooling_reference_temps::Array{Float64,1} = Float64[],
        ambient_temp_degF::Array{Float64,1} = Float64[],
        heating_load::Array{Real,1} = Real[],
        cooling_load::Array{Real,1} = Real[]
    )

    defaults = get_ashp_defaults("SpaceHeating")

    # populate defaults as needed
    if isnothing(installed_cost_per_ton)
        installed_cost_per_ton = defaults["installed_cost_per_ton"]
    end
    if isnothing(om_cost_per_ton)
        if force_into_system == true
            om_cost_per_ton = 0
        else
            om_cost_per_ton = defaults["om_cost_per_ton"]
        end
    end
    if isnothing(can_serve_cooling)
        can_serve_cooling = defaults["can_serve_cooling"]
    end
    if isnothing(force_into_system)
        force_into_system = defaults["force_into_system"]
    end
    if isnothing(back_up_temp_threshold_degF)
        back_up_temp_threshold_degF = defaults["back_up_temp_threshold_degF"]
    end
    if isnothing(max_ton)
        max_ton = defaults["max_ton"]
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

    if !isempty(heating_reference_temps)
        heating_cop, heating_cf = get_ashp_performance(heating_cop_reference,
            heating_cf_reference,
            heating_reference_temps,
            ambient_temp_degF,
            back_up_temp_threshold_degF
            )
    else
        heating_cop, heating_cf = get_default_ashp_heating(ambient_temp_degF,ambient_temp_degF)
    end

    heating_cf[heating_cop .== 1] .= 1

    if can_serve_cooling
        if !isempty(cooling_reference_temps)
            cooling_cop, cooling_cf = get_ashp_performance(cooling_cop_reference,
                cooling_cf_reference,
                cooling_reference_temps,
                ambient_temp_degF,
                -460
                )
        else
            cooling_cop, cooling_cf = get_default_ashp_cooling(ambient_temp_degF)
        end
    else
        cooling_cop = Float64[]
        cooling_cf = Float64[]
    end

    if !isnothing(min_allowable_ton)
        min_allowable_kw = min_allowable_ton * KWH_THERMAL_PER_TONHOUR
        @warn("user-provided minimum allowable ton is used in the place of the default; this may provided very small sizes if set to zero.")
    else
        min_allowable_kw = get_ashp_default_min_allowable_size(heating_load, heating_cf, cooling_load, cooling_cf)
    end

    ASHP(
        min_kw,
        max_kw,
        min_allowable_kw,
        installed_cost_per_kw,
        om_cost_per_kw,
        macrs_option_years,
        macrs_bonus_fraction,
        can_supply_steam_turbine,
        heating_cop,
        cooling_cop,
        heating_cf,
        cooling_cf,
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        can_serve_cooling,
        force_into_system,
        back_up_temp_threshold_degF,
        avoided_capex_by_ashp_present_value
    )
end


"""
ASHP Water_Heater

If a user provides the `ASHP_WaterHeater` key then the optimal scenario has the option to purchase 
this new `ASHP_WaterHeater` to meet the domestic hot water load in addition to using the `ExistingBoiler`
to meet the domestic hot water load. 

```julia
function ASHP_WaterHeater(;
    min_ton::Real = 0.0, # Minimum thermal power size
    max_ton::Real = BIG_NUMBER, # Maximum thermal power size
    min_allowable_ton::Real = 0.0 # Minimum nonzero thermal power size if included
    installed_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based cost
    om_cost_per_ton::Union{Real, nothing} = nothing, # Thermal power-based fixed O&M cost
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    can_supply_steam_turbine::Union{Bool, nothing} = nothing # If the boiler can supply steam to the steam turbine for electric production
    heating_cop::Array{<:Real,1}, # COP of the heating (i.e., thermal produced / electricity consumed)
    force_into_system::Union{Bool, Nothing} = nothing # force into system to serve all hot water loads if true
    back_up_temp_threshold_degF::Real = 10
    ambient_temp_degF::Array{Float64,1} = Float64[]
    heating_load::Array{Float64,1} # time series of site space heating load
)
```
"""
function ASHP_WaterHeater(;
    min_ton::Real = 0.0,
    max_ton::Real = BIG_NUMBER,
    min_allowable_ton::Union{Real, Nothing} = nothing,
    installed_cost_per_ton::Union{Real, Nothing} = nothing,
    om_cost_per_ton::Union{Real, Nothing} = nothing,
    macrs_option_years::Int = 0,
    macrs_bonus_fraction::Real = 0.0,
    avoided_capex_by_ashp_present_value::Real = 0.0,
    force_into_system::Union{Bool, Nothing} = nothing,
    heating_cop_reference::Array{Float64,1} = Float64[],
    heating_cf_reference::Array{Float64,1} = Float64[],
    heating_reference_temps::Array{Float64,1} = Float64[],
    back_up_temp_threshold_degF::Union{Real, Nothing} = nothing,
    ambient_temp_degF::Array{Float64,1} = Float64[],
    heating_load::Array{Real,1} = Real[]
    )

    defaults = get_ashp_defaults("DomesticHotWater")

    # populate defaults as needed
    if isnothing(installed_cost_per_ton)
        installed_cost_per_ton = defaults["installed_cost_per_ton"]
    end
    if isnothing(om_cost_per_ton)
        if force_into_system == true
            om_cost_per_ton = 0
        else
            om_cost_per_ton = defaults["om_cost_per_ton"]
        end
    end
    if isnothing(force_into_system)
        force_into_system = defaults["force_into_system"]
    end
    if isnothing(back_up_temp_threshold_degF)
        back_up_temp_threshold_degF = defaults["back_up_temp_threshold_degF"]
    end

    if isnothing(max_ton)
        max_ton = defaults["max_ton"]
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

    if !isempty(heating_reference_temps)
        heating_cop, heating_cf = get_ashp_performance(heating_cop_reference,
            heating_cf_reference,
            heating_reference_temps,
            ambient_temp_degF,
            back_up_temp_threshold_degF
            )
    else
        heating_cop, heating_cf = get_default_ashp_heating(ambient_temp_degF,back_up_temp_threshold_degF)
    end
    
    heating_cf[heating_cop .== 1] .= 1

    if !isnothing(min_allowable_ton)
        min_allowable_kw = min_allowable_ton * KWH_THERMAL_PER_TONHOUR
        @warn("user-provided minimum allowable ton is used in the place of the default; this may provided very small sizes if set to zero.")
    else
        min_allowable_kw = get_ashp_default_min_allowable_size(heating_load, heating_cf)
    end

    ASHP(
        min_kw,
        max_kw,
        min_allowable_kw,
        installed_cost_per_kw,
        om_cost_per_kw,
        macrs_option_years,
        macrs_bonus_fraction,
        can_supply_steam_turbine,
        heating_cop,
        Float64[],
        heating_cf,
        Float64[],
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        can_serve_cooling,
        force_into_system,
        back_up_temp_threshold_degF,
        avoided_capex_by_ashp_present_value
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

"""
function get_ashp_performance(cop_reference,
                cf_reference,
                reference_temps,
                ambient_temp_degF,
                back_up_temp_threshold_degF = 10.0
                )
"""
function get_ashp_performance(cop_reference,
    cf_reference,
    reference_temps,
    ambient_temp_degF,
    back_up_temp_threshold_degF = 10.0
    )
    num_timesteps = length(ambient_temp_degF)
    cop = zeros(num_timesteps)
    cf = zeros(num_timesteps)
    for ts in 1:num_timesteps
        if ambient_temp_degF[ts] < reference_temps[1] && ambient_temp_degF[ts] < last(reference_temps)
            cop[ts] = cop_reference[argmin(reference_temps)]
            cf[ts] = cf_reference[argmin(reference_temps)]
        elseif ambient_temp_degF[ts] > reference_temps[1] && ambient_temp_degF[ts] > last(reference_temps)
            cop[ts] = cop_reference[argmax(reference_temps)]
            cf[ts] = cf_reference[argmax(reference_temps)]
        else
            for i in 2:length(reference_temps)
                if ambient_temp_degF[ts] >= min(reference_temps[i-1], reference_temps[i]) &&
                    ambient_temp_degF[ts] <= max(reference_temps[i-1], reference_temps[i])
                    cop[ts] = cop_reference[i-1] + (cop_reference[i]-cop_reference[i-1])*(ambient_temp_degF[ts]-reference_temps[i-1])/(reference_temps[i]-reference_temps[i-1])
                    cf[ts] = cf_reference[i-1] + (cf_reference[i]-cf_reference[i-1])*(ambient_temp_degF[ts]-reference_temps[i-1])/(reference_temps[i]-reference_temps[i-1])
                    break
                end
            end
        end
        if ambient_temp_degF[ts] < back_up_temp_threshold_degF
            cop[ts] = 1.0
            cf[ts] = 1.0
        end
    end
    return cop, cf
end

"""
function get_default_ashp_heating(ambient_temp_degF, back_up_temp_threshold_degF)

Obtains the default ASHP heating COP and CF profiles.

ambient_temp_degF::Array{Float64,1} -- time series ambient temperature in degrees Fahrenheit
back_up_temp_threshold::Float64 -- temperature threshold at which resistive backup heater turns on
"""
function get_default_ashp_heating(ambient_temp_degF, back_up_temp_threshold_degF)
    heating_cop = round.(0.0462 .* ambient_temp_degF .+ 1.351, digits=3)
    heating_cop[ambient_temp_degF .<= back_up_temp_threshold_degF] .= 1
    heating_cf = round.(0.0116 .* ambient_temp_degF .+ 0.4556, digits=3)
    heating_cf[heating_cop .== 1.0] .= 1.0
    return heating_cop, heating_cf
end

"""
function get_default_ashp_cooling(ambient_temp_degF)

Obtains the default ASHP cooling COP and CF profiles.

ambient_temp_degF::Array{Float64,1} -- time series ambient temperature in degrees Fahrenheit
"""
function get_default_ashp_cooling(ambient_temp_degF)
    cooling_cop = round.(-0.044 .* ambient_temp_degF .+ 6.822, digits=3)
    cooling_cf = round.(-0.0056 .* ambient_temp_degF .+ 1.4778, digits=3)
    return cooling_cop, cooling_cf
end

"""
function get_ashp_default_min_allowable_size(heating_load::Array{Float64},  # time series of heating load
    heating_cf::Array{Float64,1},   # time series of capacity factor for heating
    cooling_load::Array{Float64,1} = Float64[], # # time series of capacity factor for heating
    cooling_cf::Array{Float64,1} = Float64[], # time series of capacity factor for heating
    peak_load_thermal_factor::Float64 = 0.5 # peak load multiplier for minimum allowable size           
    )

Obtains the default minimum allowable size for ASHP system.  This is calculated as half of the peak site thermal load(s) addressed by the system, including the capacity factor
"""
function get_ashp_default_min_allowable_size(heating_load::Array{Real,1}, 
    heating_cf::Array{Float64,1}, 
    cooling_load::Array{Real,1} = Real[], 
    cooling_cf::Array{Float64,1} = Float64[],
    peak_load_thermal_factor::Float64 = 0.5
    )

    println(heating_load)
    println(heating_cf)
    println(cooling_load)
    println(cooling_cf)
    if isempty(cooling_cf)
        peak_load = maximum(heating_load ./ heating_cf)
    else
        peak_load = maximum( (heating_load ./ heating_cf) .+ (cooling_load ./ cooling_cf) )
    end

    return peak_load_thermal_factor * peak_load
end

