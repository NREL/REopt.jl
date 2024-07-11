struct ConcentratingSolar <: AbstractThermalTech
    min_kw::Real
    max_kw::Real
    production_factor::AbstractVector{<:Real}
    elec_consumption_factor::AbstractVector{<:Real}
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    om_cost_per_kwh::Real
    acres_per_kw::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    tech_type::String
    can_supply_steam_turbine::Bool
    can_serve_dhw::Bool
    can_serve_space_heating::Bool
    can_serve_process_heat::Bool
    charge_storage_only::Bool
    emissions_factor_lb_CO2_per_mmbtu::Real
    emissions_factor_lb_NOx_per_mmbtu::Real
    emissions_factor_lb_SO2_per_mmbtu::Real
    emissions_factor_lb_PM25_per_mmbtu::Real
end

"""
    ConcentratingSolar

If a user provides the `ConcentratingSolar` key then the optimal scenario has the option to purchase this new 
`ConcentratingSolar` technology to meet compatible heating loads in addition to using the `ExistingBoiler` 
to meet the heating load(s). 

```julia
function ConcentratingSolar(;
    min_mmbtu_per_hour::Real = 0.0, # Minimum thermal power size
    max_mmbtu_per_hour::Real = BIG_NUMBER, # Maximum thermal power size
    production_factor::AbstractVector{<:Real} = Float64[],  production factor
    elec_consumption_factor::AbstractVector{<:Real} = Float64[], electric consumption factor per kw TODO: (do we need? are we including parasitics?) 
    acres_per_kw::Real = 0, # 
    macrs_option_years::Int = 0, # MACRS schedule for financial analysis. Set to zero to disable
    macrs_bonus_fraction::Real = 0.0, # Fraction of upfront project costs to depreciate under MACRS
    installed_cost_per_kw::Real = 293000.0, # Thermal power-based cost
    om_cost_per_kw::Real = 2930.0, # Thermal power-based fixed O&M cost
    om_cost_per_kwh::Real = 0.0, # Thermal energy-based variable O&M cost
    fuel_type::String = "natural_gas",  # "restrict_to": ["natural_gas", "landfill_bio_gas", "propane", "diesel_oil", "uranium"]
    can_supply_steam_turbine::Bool = true # If the boiler can supply steam to the steam turbine for electric production
    can_serve_dhw::Bool = true # If Boiler can supply heat to the domestic hot water load
    can_serve_space_heating::Bool = true # If Boiler can supply heat to the space heating load
    can_serve_process_heat::Bool = true # If Boiler can supply heat to the process heating load
    charge_stoarge_only::Bool = true # If ConcentratingSolar can only supply hot TES (i.e., cannot meet load directly)
    emissions_factor_lb_CO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_CO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_NOx_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_NOx_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_SO2_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_SO2_per_mmbtu"],fuel_type,0)
    emissions_factor_lb_PM25_per_mmbtu::Real = get(FUEL_DEFAULTS["emissions_factor_lb_PM25_per_mmbtu"],fuel_type,0)
)
```
"""
function ConcentratingSolar(;
        min_kw::Real = 0.0,
        max_kw::Real = BIG_NUMBER,
        production_factor::AbstractVector{<:Real} = Float64[],
        elec_consumption_factor::AbstractVector{<:Real} = Float64[],
        macrs_option_years::Int = 0,
        macrs_bonus_fraction::Real = 0.0,
        installed_cost_per_kw::Real = 2000.0,
        om_cost_per_kw::Real = 39.6,  #per kw per year
        om_cost_per_kwh::Real = 0.0,   #per kwh produced
        tech_type::String = "parabolic_trough",  # "restrict_to": ["parabolic_trough", "power_tower", "linear_fresnal", "dish_engine"]
        can_supply_steam_turbine::Bool = true,
        can_serve_dhw::Bool = true,
        can_serve_space_heating::Bool = true,
        can_serve_process_heat::Bool = true,
        charge_storage_only::Bool = true,
        emissions_factor_lb_CO2_per_mmbtu::Real = 0.0,
        emissions_factor_lb_NOx_per_mmbtu::Real = 0.0,
        emissions_factor_lb_SO2_per_mmbtu::Real = 0.0,
        emissions_factor_lb_PM25_per_mmbtu::Real = 0.0,
    )

    if isempty(production_factor)
        throw(@error("The ConcentratingSolar.production_factor is a required input when modeling a heating load which is served by the ConcentratedSolar system in the optimal case"))
    end
    if isempty(elec_consumption_factor)
        throw(@error("The ConcentratingSolar.elec_consumption_factor is a required input when modeling a heating load which is served by the ConcentratedSolar system in the optimal case"))
    end

    """
    min_kw = min_mmbtu_per_hour * KWH_PER_MMBTU
    max_kw = max_mmbtu_per_hour * KWH_PER_MMBTU

    # Convert cost basis of mmbtu/mmbtu_per_hour to kwh/kw
    installed_cost_per_kw = installed_cost_per_mmbtu_per_hour / KWH_PER_MMBTU
    om_cost_per_kw = om_cost_per_mmbtu_per_hour / KWH_PER_MMBTU
    om_cost_per_kwh = om_cost_per_mmbtu / KWH_PER_MMBTU
    """

    ConcentratingSolar(
        min_kw,
        max_kw,
        efficiency,
        production_factor,
        elec_consumption_factor,
        installed_cost_per_kw,
        om_cost_per_kw,
        om_cost_per_kwh,
        macrs_option_years,
        macrs_bonus_fraction,
        tech_type,
        can_supply_steam_turbine,
        can_serve_dhw,
        can_serve_space_heating,
        can_serve_process_heat,
        charge_stoarge_only,
        emissions_factor_lb_CO2_per_mmbtu,
        emissions_factor_lb_NOx_per_mmbtu,
        emissions_factor_lb_SO2_per_mmbtu,
        emissions_factor_lb_PM25_per_mmbtu
    )
end
