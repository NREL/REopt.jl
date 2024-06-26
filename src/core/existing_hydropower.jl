# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ExistingHydropower` is an optional REopt input with the following keys and default values:
```julia
    existing_kw_per_turbine::Real=0,
    number_of_turbines::Real=0, 
    computation_type::String="average_power_conversion", # "average_power_conversion", "quadratic_partially_discretized", "fixed_efficiency_linearized_reservoir_head", or "quadratic_unsimplified"
    average_cubic_meters_per_second_per_kw::Real=0, # only applied when the computation_type = "average_power_conversion"
    coefficient_a_efficiency::Real=0.0, 
    coefficient_b_efficiency::Real=0.0,
    coefficient_c_efficiency::Real=0.0,
    coefficient_d_reservoir_head::Real=0.0, # coefficient for a quadratic term for the reservoir head equation, which is only applied when the computation_type = "quadratic_unsimplified"
    coefficient_e_reservoir_head::Real=0.0,
    coefficient_f_reservoir_head::Real=0.0, 
    number_of_efficiency_bins::Real=3, # only applied when the computation_type = "quadratic_partially_discretized"
    fixed_turbine_efficiency::Real=0.9, # only applied when the computation_type = "fixed_efficiency_linearized_reservoir_head"
    water_inflow_cubic_meter_per_second::Array=[], # tributary water flowing into the dam's pond
    cubic_meter_maximum::Real=0, #maximum capacity of the dam
    cubic_meter_minimum::Real=0, #minimum water level of the dam
    initial_reservoir_volume::Real=0.0  # The initial volume of water in the reservoir
    minimum_water_output_cubic_meter_per_second_total_of_all_turbines::Real=0,
    minimum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
    maximum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
    minimum_operating_time_steps_individual_turbine::Real=0.0, # the minimum time (in time steps) that an invidual turbine must run for (can avoid turning a turbine on for just 15 minute, for instance)
    spillway_maximum_cubic_meter_per_second::Real=nothing # maximum water flow that can flow out of the spillway (structure that enables water overflowing from the reservoir to pass over/through the dam)
    hydro_production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing, # Optional user-defined production factors. Must be normalized to units of kW-AC/kW-DC nameplate. The series must be one year (January through December) of hourly, 30-minute, or 15-minute generation data.
    can_net_meter::Bool = off_grid_flag ? false : true,
    can_wholesale::Bool = off_grid_flag ? false : true,
    can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
    can_curtail::Bool = true,
```
"""

mutable struct ExistingHydropower <: AbstractTech

    existing_kw_per_turbine
    number_of_turbines
    computation_type
    average_cubic_meters_per_second_per_kw
    coefficient_a_efficiency 
    coefficient_b_efficiency
    coefficient_c_efficiency
    coefficient_d_reservoir_head
    coefficient_e_reservoir_head
    coefficient_f_reservoir_head
    number_of_efficiency_bins
    fixed_turbine_efficiency
    water_inflow_cubic_meter_per_second
    cubic_meter_maximum  
    cubic_meter_minimum 
    initial_reservoir_volume 
    minimum_water_output_cubic_meter_per_second_total_of_all_turbines
    minimum_water_output_cubic_meter_per_second_per_turbine
    maximum_water_output_cubic_meter_per_second_per_turbine
    minimum_operating_time_steps_individual_turbine
    spillway_maximum_cubic_meter_per_second
    hydro_production_factor_series 
    can_net_meter  
    can_wholesale  
    can_export_beyond_nem_limit 
    can_curtail 

    function ExistingHydropower(;
        existing_kw_per_turbine::Real=0.0,
        number_of_turbines::Real=0,
        computation_type::String="average_power_conversion",
        average_cubic_meters_per_second_per_kw::Real=0.0,
        coefficient_a_efficiency::Real=0.0,
        coefficient_b_efficiency::Real=0.0,
        coefficient_c_efficiency::Real=0.0,
        coefficient_d_reservoir_head::Real=0.0,
        coefficient_e_reservoir_head::Real=0.0,
        coefficient_f_reservoir_head::Real=0.0,
        number_of_efficiency_bins::Real=3,
        fixed_turbine_efficiency::Real=0.9,
        water_inflow_cubic_meter_per_second::Union{Nothing, Array{<:Real,1}} = nothing, # water flowing into the dam's pond
        cubic_meter_maximum::Real=0.0, #maximum capacity of the reservoir
        cubic_meter_minimum::Real=0.0, #minimum water level of the reservoir
        initial_reservoir_volume::Real=0.0, # the initial volume of the reservoir
        minimum_water_output_cubic_meter_per_second_total_of_all_turbines::Real=0.0,
        minimum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
        maximum_water_output_cubic_meter_per_second_per_turbine::Real=0.0,
        minimum_operating_time_steps_individual_turbine::Real=1.0, 
        spillway_maximum_cubic_meter_per_second::Real=nothing, 
        hydro_production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing,
        can_net_meter::Bool = false,
        can_wholesale::Bool = false,
        can_export_beyond_nem_limit::Bool = false,
        can_curtail::Bool = true
        )
        
        #TODO: modify and uncomment the data checks below
        #if !(off_grid_flag) && !(operating_reserve_required_fraction == 0.0)
        #    @warn "Hydropower operating_reserve_required_fraction applies only when true. Setting operating_reserve_required_fraction to 0.0 for this on-grid analysis."
        #    operating_reserve_required_fraction = 0.0
        #end
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
            computation_type,
            average_cubic_meters_per_second_per_kw,
            coefficient_a_efficiency,
            coefficient_b_efficiency,
            coefficient_c_efficiency,
            coefficient_d_reservoir_head,
            coefficient_e_reservoir_head,
            coefficient_f_reservoir_head,
            number_of_efficiency_bins,
            fixed_turbine_efficiency,
            water_inflow_cubic_meter_per_second,
            cubic_meter_maximum,
            cubic_meter_minimum,
            initial_reservoir_volume,
            minimum_water_output_cubic_meter_per_second_total_of_all_turbines,
            minimum_water_output_cubic_meter_per_second_per_turbine,
            maximum_water_output_cubic_meter_per_second_per_turbine,
            minimum_operating_time_steps_individual_turbine,
            spillway_maximum_cubic_meter_per_second,
            hydro_production_factor_series,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail
        )
    end
end

