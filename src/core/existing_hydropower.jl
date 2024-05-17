# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingHydropower` is an optional REopt input with the following keys and default values:
```julia
    existing_kw_per_turbine::Real=0,
    number_of_turbines::Real=0,
    use_average_power_conversion::String="yes",
    average_cubic_meters_per_second_per_kw::Real=0,
    efficiency_slope_fraction_per_cubic_meter_per_second::Real=0, # slope of efficiency plot with the cubic meter per second on the x axis and the percent efficiency on the y axis
    efficiency_fraction_y_intercept # the y intercept of the linearized turbine efficiency plot
    linearized_stage_storage_slope  # slope of plot with reservoir volume on the x axis and water elevation on the y axis
    water_inflow_cubic_meter_per_second::Array=[], # water flowing into the dam's pond
    cubic_meter_maximum::Real=0, #maximum capacity of the dam
    cubic_meter_minimum::Real=0, #minimum water level of the dam
    initial_reservoir_volume::Real=0.0  # The initial volume of water in the reservoir
    minimum_water_output_cubic_meter_per_second_total_of_all_turbines::Real=0,
    minimum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
    spillway_maximum_cubic_meter_per_second::Real=nothing # maximum water flow that can flow out of the spillway (structure that enables water overflowing from the reservoir to pass over/through the dam)
    hydro_production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing, # Optional user-defined production factors. Must be normalized to units of kW-AC/kW-DC nameplate. The series must be one year (January through December) of hourly, 30-minute, or 15-minute generation data.
    can_net_meter::Bool = off_grid_flag ? false : true,
    can_wholesale::Bool = off_grid_flag ? false : true,
    can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
    can_curtail::Bool = true,
```
"""
# Based this code on the srv>core>pv.jl code
mutable struct ExistingHydropower <: AbstractTech

    existing_kw_per_turbine  #::Float64
    number_of_turbines
    use_average_power_conversion
    average_cubic_meters_per_second_per_kw
    efficiency_slope_fraction_per_cubic_meter_per_second  #::Float64
    efficiency_fraction_y_intercept 
    linearized_stage_storage_slope 
    water_inflow_cubic_meter_per_second  #::AbstractArray{Float64,1}
    cubic_meter_maximum  #::Float64
    cubic_meter_minimum  #::Float64
    initial_reservoir_volume 
    minimum_water_output_cubic_meter_per_second_total_of_all_turbines  #::Float64
    minimum_water_output_cubic_meter_per_second_per_turbine
    spillway_maximum_cubic_meter_per_second
    hydro_production_factor_series  #::AbstractArray{Float64,1}
    can_net_meter  #::Bool 
    can_wholesale  #::Bool
    can_export_beyond_nem_limit  #::Bool
    can_curtail  #::Bool

    function ExistingHydropower(;
        existing_kw_per_turbine::Real=0.0,
        number_of_turbines::Real=0,
        use_average_power_conversion::String="yes",
        average_cubic_meters_per_second_per_kw::Real=0.0,
        efficiency_slope_fraction_per_cubic_meter_per_second::Real=0.0, # conversion factor for the water turbines
        efficiency_fraction_y_intercept::Real=1.0,
        linearized_stage_storage_slope::Real=0.0, 
        water_inflow_cubic_meter_per_second::Union{Nothing, Array{<:Real,1}} = nothing, # water flowing into the dam's pond
        cubic_meter_maximum::Real=0.0, #maximum capacity of the dam
        cubic_meter_minimum::Real=0.0, #minimum water level of the dam
        initial_reservoir_volume::Real=0.0, # the initial volume of the reservoir
        minimum_water_output_cubic_meter_per_second_total_of_all_turbines::Real=0.0,
        minimum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
        spillway_maximum_cubic_meter_per_second::Real=nothing, 
        hydro_production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing,
        can_net_meter::Bool = false,
        can_wholesale::Bool = false,
        can_export_beyond_nem_limit::Bool = false,
        can_curtail::Bool = true
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
            existing_kw_per_turbine,
            number_of_turbines,
            use_average_power_conversion,
            average_cubic_meters_per_second_per_kw,
            efficiency_slope_fraction_per_cubic_meter_per_second,
            efficiency_fraction_y_intercept,
            linearized_stage_storage_slope,
            water_inflow_cubic_meter_per_second,
            cubic_meter_maximum,
            cubic_meter_minimum,
            initial_reservoir_volume,
            minimum_water_output_cubic_meter_per_second_total_of_all_turbines,
            minimum_water_output_cubic_meter_per_second_per_turbine,
            spillway_maximum_cubic_meter_per_second,
            hydro_production_factor_series,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail
        )
    end
end

