# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingHydropower` is an optional REopt input with the following keys and default values:
```julia
    existing_kw::Real=0,
    efficiency_kwh_per_cubicmeter::Real=0, # conversion factor for the water turbines
    water_inflow_cubic_meter_per_second::Array=[], # water flowing into the dam's pond
    cubic_meter_maximum::Real=0, #maximum capacity of the dam
    cubic_meter_minimum::Real=0, #minimum water level of the dam
    minimum_water_output_cubic_meter_per_second::Real=0,
    production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing, # Optional user-defined production factors. Must be normalized to units of kW-AC/kW-DC nameplate. The series must be one year (January through December) of hourly, 30-minute, or 15-minute generation data.
    can_net_meter::Bool = off_grid_flag ? false : true,
    can_wholesale::Bool = off_grid_flag ? false : true,
    can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
    can_curtail::Bool = true,
```
"""
struct ExistingHydropower <: AbstractTech

    existing_kw::Float64
    efficiency_kwh_per_cubicmeter::Float64
    water_inflow_cubic_meter_per_second::AbstractArray{Float64,1}
    cubic_meter_maximum::Float64
    cubic_meter_minimum::Float64
    minimum_water_output_cubic_meter_per_second::Float64
    production_factor_series::AbstractArray{Float64,1}
    can_net_meter::Bool
    can_wholesale::Bool
    can_export_beyond_nem_limit::Bool
    can_curtail::Bool

    function ExistingHydropower(;
        existing_kw=0.0,
        efficiency_kwh_per_cubicmeter=0.0, # conversion factor for the water turbines
        water_inflow_cubic_meter_per_second=[], # water flowing into the dam's pond
        cubic_meter_maximum=0.0, #maximum capacity of the dam
        cubic_meter_minimum=100.0, #minimum water level of the dam
        minimum_water_output_cubic_meter_per_second=0.0,
        production_factor_series= [],
        can_net_meter = false,
        can_wholesale = false,
        can_export_beyond_nem_limit = false,
        can_curtail = true
         )
        
        #if !(off_grid_flag) && !(operating_reserve_required_fraction == 0.0)
        #    @warn "Hydropower operating_reserve_required_fraction applies only when true. Setting operating_reserve_required_fraction to 0.0 for this on-grid analysis."
        #    operating_reserve_required_fraction = 0.0
        #end
        #TODO: activate the if statement below
        #=
        if off_grid_flag && (can_net_meter || can_wholesale || can_export_beyond_nem_limit)
            @warn "Setting Existing Hydropower can_net_meter, can_wholesale, and can_export_beyond_nem_limit to False because `off_grid_flag` is true."
            can_net_meter = false
            can_wholesale = false
            can_export_beyond_nem_limit = false
        end
        =#
        # validate inputs
        #invalid_args = String[]
        #if !(0 <= azimuth < 360)
        #    push!(invalid_args, "azimuth must satisfy 0 <= azimuth < 360, got $(azimuth)")
        #end

        new(
            existing_kw,
            efficiency_kwh_per_cubicmeter,
            water_inflow_cubic_meter_per_second,
            cubic_meter_maximum,
            cubic_meter_minimum,
            minimum_water_output_cubic_meter_per_second,
            production_factor_series,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail
        )
    end
end

