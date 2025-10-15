# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricLoad` is a required REopt input with the following keys and default values:
```julia
    loads_kw::Array{<:Real,1} = Real[],
    normalize_and_scale_load_profile_input::Bool = false,  # Takes loads_kw and normalizes and scales it to annual_kwh or monthly_totals_kwh
    path_to_csv::String = "", # for csv containing loads_kw
    doe_reference_name::String = "",
    blended_doe_reference_names::Array{String, 1} = String[],
    blended_doe_reference_percents::Array{<:Real,1} = Real[], # Values should be between 0-1 and sum to 1.0
    year::Union{Int, Nothing} = doe_reference_name ≠ "" || blended_doe_reference_names ≠ String[] ? 2017 : nothing, # used in ElectricTariff to align rate schedule with weekdays/weekends. DOE CRB profiles defaults to using 2017. If providing load data, specify year of data.
    city::String = "",
    annual_kwh::Union{Real, Nothing} = nothing,
    monthly_totals_kwh::Array{<:Real,1} = Real[],
    critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
    loads_kw_is_net::Bool = true,
    critical_loads_kw_is_net::Bool = false,
    critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # if off grid must be 1.0, else 0.5
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%. Applied to each time_step as a % of electric load.
    min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0, # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
    # NEW: Multiple load components support
    load_components::Dict{String, <:Any} = Dict{String, Any}(),  # Dictionary of load components from different years to align
    leap_policy::String = "truncate_dec31",  # How to handle leap years: "truncate_dec31" (default) or "drop_feb29"
    preserve_component_data::Bool = true  # Whether to store component breakdown in results (default: true)
```

!!! note "Required inputs"
    Must provide either `loads_kw` or `path_to_csv` or [`doe_reference_name` and `city`] or `doe_reference_name` or [`blended_doe_reference_names` and `blended_doe_reference_percents`] or `load_components`. 

    When only `doe_reference_name` is provided the `Site.latitude` and `Site.longitude` are used to look up the ASHRAE climate zone, which determines the appropriate DoE Commercial Reference Building profile.

    When using the [`doe_reference_name` and `city`] option, choose `city` from one of the cities used to represent the ASHRAE climate zones:
    - Albuquerque
    - Atlanta
    - Baltimore
    - Boulder
    - Chicago
    - Duluth
    - Fairbanks
    - Helena
    - Houston
    - LosAngeles
    - LasVegas
    - Miami
    - Minneapolis
    - Phoenix
    - SanFrancisco
    - Seattle
    and `doe_reference_name` from:
    - FastFoodRest
    - FullServiceRest
    - Hospital
    - LargeHotel
    - LargeOffice
    - MediumOffice
    - MidriseApartment
    - Outpatient
    - PrimarySchool
    - RetailStore
    - SecondarySchool
    - SmallHotel
    - SmallOffice
    - StripMall
    - Supermarket
    - Warehouse
    - FlatLoad # constant load year-round
    - FlatLoad_24_5 # constant load all hours of the weekdays
    - FlatLoad_16_7 # two 8-hour shifts for all days of the year; 6-10 a.m.
    - FlatLoad_16_5 # two 8-hour shifts for the weekdays; 6-10 a.m.
    - FlatLoad_8_7 # one 8-hour shift for all days of the year; 9 a.m.-5 p.m.
    - FlatLoad_8_5 # one 8-hour shift for the weekdays; 9 a.m.-5 p.m.

    Each `city` and `doe_reference_name` combination has a default `annual_kwh`, or you can provide your
    own `annual_kwh` or `monthly_totals_kwh` and the reference profile will be scaled appropriately.


!!! note "Year" 
    The ElectricLoad `year` is used in ElectricTariff to align rate schedules with weekdays/weekends. If providing your own `loads_kw`, ensure the `year` matches the year of your data.
    If utilizing `doe_reference_name` or `blended_doe_reference_names`, the default year of 2017 is used because these load profiles start on a Sunday.
    When using `load_components`, the `year` parameter specifies the target year for alignment (defaults to current year if not specified).

!!! note "Multiple Load Components (New Feature)"
    Use `load_components` to combine loads from different source years (e.g., site load from 2016, EV load from 2024).
    REopt automatically aligns all components to the `year` parameter while preserving:
    - Weekday/weekend patterns (critical for TOU rate accuracy)
    - Total energy consumption (<0.0001% error)
    - Monthly energy distributions
    
    Each component must be a dictionary with:
    - `"loads_kw"`: Vector of hourly loads (8760 or 8784 hours) OR `"doe_reference_name"` with optional `"annual_kwh"`
    - `"year"`: Integer year of the source data
    
    Example:
    ```julia
    load_components = Dict(
        "site_load" => Dict("loads_kw" => site_loads_2016, "year" => 2016),
        "ev_load" => Dict("loads_kw" => ev_loads_2024, "year" => 2024)
    )
    year = 2025  # Target alignment year
    ```
"""
mutable struct ElectricLoad  # mutable to adjust (critical_)loads_kw based off of (critical_)loads_kw_is_net
    loads_kw::Array{Real,1}
    year::Int  # used in ElectricTariff to align rate schedule with weekdays/weekends
    critical_loads_kw::Array{Real,1}
    loads_kw_is_net::Bool
    critical_loads_kw_is_net::Bool
    city::String
    operating_reserve_required_fraction::Real
    min_load_met_annual_fraction::Real
    
    # NEW: Component preservation (optional) - for multiple load types support
    component_loads::Union{Dict{String, Vector{Real}}, Nothing}
    component_metadata::Union{Dict{String, Any}, Nothing}
    has_components::Bool
    
    function ElectricLoad(;
        off_grid_flag::Bool = false,
        loads_kw::Array{<:Real,1} = Real[],
        normalize_and_scale_load_profile_input::Bool = false,
        path_to_csv::String = "",
        doe_reference_name::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        year::Union{Int, Nothing} = doe_reference_name ≠ "" || blended_doe_reference_names ≠ String[] ? 2017 : nothing, # used in ElectricTariff to align rate schedule with weekdays/weekends. DOE CRB profiles 2017 by default. If providing load data, specify year of data.
        city::String = "",
        annual_kwh::Union{Real, Nothing} = nothing,
        monthly_totals_kwh::Array{<:Real,1} = Real[],
        critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
        loads_kw_is_net::Bool = true,
        critical_loads_kw_is_net::Bool = false,
        critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # if off grid, must be 1.0, else 0.5
        latitude::Real,
        longitude::Real,
        time_steps_per_hour::Int = 1,
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%
        min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0, # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
        # NEW: Multiple load components support
        load_components::Dict{String, <:Any} = Dict{String, Any}(),
        leap_policy::String = "truncate_dec31",
        preserve_component_data::Bool = true
        )
        
        if off_grid_flag
            if !isnothing(critical_loads_kw)
                @warn "ElectricLoad critical_loads_kw will be ignored because `off_grid_flag` is true. If you wish to alter the load profile or load met, adjust the loads_kw or min_load_met_annual_fraction."
                critical_loads_kw = nothing
            end
            if critical_load_fraction != 1.0
                @warn "ElectricLoad critical_load_fraction must be 1.0 (100%) for off-grid scenarios. Any other value will be overriden when `off_grid_flag` is true. If you wish to alter the load profile or load met, adjust the loads_kw or min_load_met_annual_fraction."
                critical_load_fraction = 1.0
            end
        end

        if !(off_grid_flag)
            if !(operating_reserve_required_fraction == 0.0)
                @warn "ElectricLoad operating_reserve_required_fraction must be 0 for on-grid scenarios. Operating reserve requirements apply to off-grid scenarios only."
                operating_reserve_required_fraction = 0.0
            elseif !(min_load_met_annual_fraction == 1.0)
                @warn "ElectricLoad min_load_met_annual_fraction must be 1.0 for on-grid scenarios. This input applies to off-grid scenarios only."
                min_load_met_annual_fraction = 1.0
            end
        end

        # NEW: Handle multiple load components if provided
        component_loads_dict = nothing
        component_metadata_dict = nothing
        has_components = false
        
        if !isempty(load_components)
            # Validate: load_components is mutually exclusive with old-style parameters
            if length(loads_kw) > 0
                @warn "ElectricLoad has both 'load_components' and 'loads_kw'. Using 'load_components' and ignoring 'loads_kw'."
            end
            if doe_reference_name != ""
                @warn "ElectricLoad has both 'load_components' and 'doe_reference_name'. Using 'load_components' and ignoring 'doe_reference_name'."
            end
            if !isempty(blended_doe_reference_names)
                @warn "ElectricLoad has both 'load_components' and 'blended_doe_reference_names'. Using 'load_components' and ignoring 'blended_doe_reference_names'."
            end
            
            # Determine target alignment year for load_components
            # If year not specified with load_components, default to current year
            if isnothing(year)
                year = Dates.year(Dates.now())
                @info "ElectricLoad: No year specified with load_components. Defaulting to $(year) for alignment."
            end
            
            target_year = year
            
            # Preprocess each component to ensure it has loads_kw
            processed_components = Dict{String, Any}()
            for (component_name, component_data) in load_components
                try
                    # println("Preprocessing component: $component_name")
                    processed_components[component_name] = preprocess_load_component(
                        component_data, latitude, longitude
                    )
                    # println("  ✓ Successfully preprocessed $component_name")
                catch e
                    println("  ✗ Error preprocessing $component_name: $e")
                    rethrow(e)
                end
            end
            
            # Align all components to reference year
            total_loads, aligned_components, metadata = align_multiple_loads_to_reference_year(
                processed_components, target_year;
                time_steps_per_hour=time_steps_per_hour,
                preserve_monthly=true,
                leap_policy=leap_policy
            )
            
            # Override loads_kw and year with aligned results
            loads_kw = total_loads
            year = target_year
            
            # Store component data if requested
            if preserve_component_data
                component_loads_dict = aligned_components
                component_metadata_dict = metadata
                has_components = true
            end
            
            # If city not provided, try to get from first component or use default
            if isempty(city)
                city = ""
            end
        end

        if isnothing(year)
            throw(@error("Must provide the year when using loads_kw input."))
        end 

        if length(loads_kw) > 0 && !normalize_and_scale_load_profile_input

            if !(length(loads_kw) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided electric load does not match the time_steps_per_hour."))
            end
        
        elseif length(loads_kw) > 0 && normalize_and_scale_load_profile_input
            if !isempty(doe_reference_name)
                @warn "loads_kw provided with normalize_and_scale_load_profile_input = true, so ignoring location and building type inputs, and only using the year and annual or monthly energy inputs with the load profile"
            end
            if isnothing(annual_kwh) && isempty(monthly_totals_kwh)
                throw(@error("Provided loads_kw with normalize_and_scale_load_profile_input=true, but no annual_kwh or monthly_totals_kwh was provided"))
            end
            # Using dummy values for all unneeded location and building type arguments for normalizing and scaling load profile input
            normalized_profile = loads_kw ./ sum(loads_kw)
            loads_kw = BuiltInElectricLoad("Chicago", "LargeOffice", 41.8333, -88.0616, year, annual_kwh, monthly_totals_kwh, normalized_profile, leap_policy)            

        elseif !isempty(path_to_csv)
            try
                loads_kw = vec(readdlm(path_to_csv, ',', Float64, '\n'))
            catch e
                throw(@error("Unable to read in electric load profile from $path_to_csv. Please provide a valid path to a csv with no header."))
            end

            if !(length(loads_kw) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided electric load does not match the time_steps_per_hour."))
            end
    
        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, year, annual_kwh, monthly_totals_kwh, Real[], leap_policy)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInElectricLoad, latitude, longitude, year, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_kwh, monthly_totals_kwh, 1.0, nothing, "", leap_policy)
        else
            throw(@error("Cannot construct ElectricLoad. You must provide either [loads_kw], [doe_reference_name, city], 
                  [doe_reference_name, latitude, longitude], 
                  or [blended_doe_reference_names, blended_doe_reference_percents] with city or latitude and longitude."))
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating electric loads in each hour to match the time_steps_per_hour."
        end

        if isnothing(critical_loads_kw)
            critical_loads_kw = critical_load_fraction * loads_kw
        end

        new(
            loads_kw,
            year,
            critical_loads_kw,
            loads_kw_is_net,
            critical_loads_kw_is_net,
            city,
            operating_reserve_required_fraction,
            min_load_met_annual_fraction,
            component_loads_dict,
            component_metadata_dict,
            has_components
        )
    end
end

"""
    preprocess_load_component(component_data::Dict, latitude::Real, longitude::Real)

Preprocess a load component to ensure it has loads_kw and year fields.
This function mirrors the logic from the ElectricLoad constructor for generating load profiles.

# Component Input Options
1. Direct loads with loads_kw array and year
2. DOE reference building with doe_reference_name, city, annual_kwh (optional), and year
3. CSV file with path_to_csv and year
4. Blended DOE profiles with blended_doe_reference_names, blended_doe_reference_percents, and year

# Returns
- Dict with loads_kw (Vector{Float64}) and year (Int) fields
"""
function preprocess_load_component(component_data::Dict, 
                                   latitude::Real, 
                                   longitude::Real)::Dict{String, Any}
    
    processed = Dict{String, Any}(component_data)
    
    # If already has loads_kw, just validate year is present
    if haskey(processed, "loads_kw")
        if !haskey(processed, "year")
            throw(ArgumentError("Component with 'loads_kw' must also specify 'year'"))
        end
        return processed
    end
    
    # Extract common parameters (with same defaults as ElectricLoad constructor)
    year = get(processed, "year", 2017)
    annual_kwh = get(processed, "annual_kwh", nothing)
    city = get(processed, "city", "")
    
    # Convert monthly_totals_kwh to concrete type (matching ElectricLoad behavior)
    monthly_totals_kwh_raw = get(processed, "monthly_totals_kwh", Real[])
    monthly_totals_kwh = isempty(monthly_totals_kwh_raw) ? Float64[] : Float64.(monthly_totals_kwh_raw)
    
    # Generate loads_kw based on input method (matching ElectricLoad constructor order)
    local loads_kw::Vector{Float64}
    
    # Option 1: CSV file path
    if haskey(processed, "path_to_csv") && !isempty(processed["path_to_csv"])
        path = processed["path_to_csv"]
        try
            loads_kw = vec(readdlm(path, ',', Float64, '\n'))
        catch e
            throw(ArgumentError("Unable to read electric load profile from $path. Please provide a valid path to a csv with no header."))
        end
        if !haskey(processed, "year")
            throw(ArgumentError("Component with 'path_to_csv' must also specify 'year'"))
        end
    
    # Option 2: DOE reference building
    elseif haskey(processed, "doe_reference_name") && !isempty(processed["doe_reference_name"])
        doe_reference_name = processed["doe_reference_name"]
        loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, 
                                       year, annual_kwh, monthly_totals_kwh)
    
    # Option 3: Blended DOE profiles
    elseif haskey(processed, "blended_doe_reference_names") && 
           !isempty(processed["blended_doe_reference_names"])
        
        # Convert to concrete types (matching ElectricLoad behavior)
        blended_names = String.(processed["blended_doe_reference_names"])
        blended_percents_raw = get(processed, "blended_doe_reference_percents", Real[])
        blended_percents = Float64.(blended_percents_raw)
        
        # Validate inputs
        if isempty(blended_percents) || length(blended_names) != length(blended_percents)
            throw(ArgumentError("blended_doe_reference_names and blended_doe_reference_percents must have same length"))
        end
        if !isapprox(sum(blended_percents), 1.0, atol=0.001)
            throw(ArgumentError("blended_doe_reference_percents must sum to 1.0"))
        end
        
        # Call blend_and_scale_doe_profiles (matching ElectricLoad constructor signature)
        loads_kw = blend_and_scale_doe_profiles(BuiltInElectricLoad, latitude, longitude, 
                                                year, blended_names, blended_percents, city,
                                                annual_kwh, monthly_totals_kwh)
    
    else
        throw(ArgumentError("Component must provide either 'loads_kw', 'doe_reference_name', 'blended_doe_reference_names', or 'path_to_csv'"))
    end
    
    # Set loads_kw and year in processed dict
    processed["loads_kw"] = loads_kw
    processed["year"] = year
    
    return processed
end


function BuiltInElectricLoad(
    city::String,
    buildingtype::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    annual_kwh::Union{Real, Nothing}=nothing,
    monthly_totals_kwh::Vector{<:Real}=Real[],
    normalized_profile::Union{Vector{Float64}, Vector{<:Real}}=Real[],
    leap_policy::String="truncate_dec31"
    )
    
    electric_annual_kwh = JSON.parsefile(joinpath(@__DIR__, "..", "..", "data", "load_profiles", "total_electric_annual_kwh.json"))

    if !(buildingtype in DEFAULT_BUILDINGS)
        throw(@error("buildingtype $(buildingtype) not in $(DEFAULT_BUILDINGS)."))
    end

    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end

    if isnothing(annual_kwh)
        # Use FlatLoad annual_kwh from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_kwh = electric_annual_kwh[city][lowercase("FlatLoad")]
        else
            annual_kwh = electric_annual_kwh[city][lowercase(buildingtype)]
        end
    end

    built_in_load("electric", city, buildingtype, year, annual_kwh, monthly_totals_kwh, nothing, normalized_profile, leap_policy)
end
