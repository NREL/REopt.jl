# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
Inputs related to the physical location:

`Site` is a required REopt input with the following keys and default values:
```julia
    latitude::Real, 
    longitude::Real, 
    land_acres::Union{Real, Nothing} = nothing, # acres of land available for PV panels and/or Wind turbines. Constraint applied separately to PV and Wind, meaning the two technologies are assumed to be able to be co-located.
    roof_squarefeet::Union{Real, Nothing} = nothing,
    min_resil_time_steps::Int=0, # The minimum number consecutive timesteps that load must be fully met once an outage begins. Only applies to multiple outage modeling using inputs outage_start_time_steps and outage_durations.
    mg_tech_sizes_equal_grid_sizes::Bool = true,
    node::Int = 1,
    CO2_emissions_reduction_min_fraction::Union{Float64, Nothing} = nothing,
    CO2_emissions_reduction_max_fraction::Union{Float64, Nothing} = nothing,
    bau_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing, # Auto-populated based on BAU run. This input will be overwritten if the BAU scenario is run, but can be user-provided if no BAU scenario is run.
    bau_grid_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
    renewable_electricity_min_fraction::Real = 0.0,
    renewable_electricity_max_fraction::Union{Float64, Nothing} = nothing,
    include_exported_elec_emissions_in_total::Bool = true,
    include_exported_renewable_electricity_in_total::Bool = true,
    outdoor_air_temperature_degF::Union{Nothing, Array{<:Real,1}} = nothing,
```
"""
mutable struct Site
    "required"
    latitude
    "required"
    longitude
    land_acres
    roof_squarefeet
    min_resil_time_steps
    mg_tech_sizes_equal_grid_sizes
    CO2_emissions_reduction_min_fraction
    CO2_emissions_reduction_max_fraction
    bau_emissions_lb_CO2_per_year
    bau_grid_emissions_lb_CO2_per_year
    renewable_electricity_min_fraction
    renewable_electricity_max_fraction
    include_exported_elec_emissions_in_total
    include_exported_renewable_electricity_in_total
    outdoor_air_temperature_degF
    node  # TODO validate that multinode Sites do not share node numbers? Or just raise warning
    function Site(;
        latitude::Real, 
        longitude::Real, 
        land_acres::Union{Real, Nothing} = nothing, 
        roof_squarefeet::Union{Real, Nothing} = nothing,
        min_resil_time_steps::Int=0,
        mg_tech_sizes_equal_grid_sizes::Bool = true,
        CO2_emissions_reduction_min_fraction::Union{Float64, Nothing} = nothing,
        CO2_emissions_reduction_max_fraction::Union{Float64, Nothing} = nothing,
        bau_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
        bau_grid_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
        renewable_electricity_min_fraction::Union{Float64, Nothing} = nothing,
        renewable_electricity_max_fraction::Union{Float64, Nothing} = nothing,
        include_exported_elec_emissions_in_total::Bool = true,
        include_exported_renewable_electricity_in_total::Bool = true,
        outdoor_air_temperature_degF::Union{Nothing, Array{<:Real,1}} = nothing,
        node::Int = 1, 
        )
        invalid_args = String[]
        if !(-90 <= latitude < 90)
            push!(invalid_args, "latitude must satisfy -90 <= latitude < 90, got $(latitude)")
        end
        if !(-180 <= longitude < 180)
            push!(invalid_args, "longitude must satisfy -180 <= longitude < 180, got $(longitude)")
        end
        if !isnothing(renewable_electricity_max_fraction) && !isnothing(renewable_electricity_min_fraction)
            if (renewable_electricity_min_fraction > renewable_electricity_max_fraction)
                push!(invalid_args, "renewable_electricity_min_fraction must be less than or equal to renewable_electricity_max_fraction")
            end
        end
        if length(invalid_args) > 0
            throw(@error("Invalid Site argument values: $(invalid_args)"))
        end

        new(latitude, longitude, land_acres, roof_squarefeet, min_resil_time_steps, 
            mg_tech_sizes_equal_grid_sizes, CO2_emissions_reduction_min_fraction, 
            CO2_emissions_reduction_max_fraction, bau_emissions_lb_CO2_per_year,
            bau_grid_emissions_lb_CO2_per_year, renewable_electricity_min_fraction,
            renewable_electricity_max_fraction, include_exported_elec_emissions_in_total,
            include_exported_renewable_electricity_in_total, outdoor_air_temperature_degF, node)
    end
end