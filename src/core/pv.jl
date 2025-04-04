# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`PV` is an optional REopt input with the following keys and default values:
```julia
    array_type::Int=1, # PV Watts array type (0: Ground Mount Fixed (Open Rack); 1: Rooftop, Fixed; 2: Ground Mount 1-Axis Tracking; 3 : 1-Axis Backtracking; 4: Ground Mount, 2-Axis Tracking)
    tilt::Real = (array_type == 0 || array_type == 1) ? 20 : 0, # tilt = 20 for fixed rooftop arrays (1) or ground-mount (2) ; tilt = 0 for everything else (3 and 4)
    module_type::Int=0, # PV module type (0: Standard; 1: Premium; 2: Thin Film)
    losses::Real=0.14, # System losses
    azimuth::Real = latitude≥0 ? 180 : 0, # set azimuth to zero for southern hemisphere
    gcr::Real=0.4,  # Ground coverage ratio
    radius::Int=0, # Radius, in miles, to use when searching for the closest climate data station. Use zero to use the closest station regardless of the distance
    name::String="PV", # for use with multiple pvs 
    location::String="both", # one of ["roof", "ground", "both"]
    existing_kw::Real=0,
    min_kw::Real=0,
    max_kw::Real=1.0e9, # max new DC capacity (beyond existing_kw)
    installed_cost_per_kw::Real=1790.0,
    om_cost_per_kw::Real=18.0,
    degradation_fraction::Real=0.005,
    macrs_option_years::Int = 5,
    macrs_bonus_fraction::Real = 0.6,
    macrs_itc_reduction::Real = 0.5,
    kw_per_square_foot::Real=0.01,
    acres_per_kw::Real=6e-3,
    inv_eff::Real=0.96,
    dc_ac_ratio::Real=1.2,
    production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing, # Optional user-defined production factors. Must be normalized to units of kW-AC/kW-DC nameplate. The series must be one year (January through December) of hourly, 30-minute, or 15-minute generation data.
    federal_itc_fraction::Real = 0.3,
    federal_rebate_per_kw::Real = 0.0,
    state_ibi_fraction::Real = 0.0,
    state_ibi_max::Real = 1.0e10,
    state_rebate_per_kw::Real = 0.0,
    state_rebate_max::Real = 1.0e10,
    utility_ibi_fraction::Real = 0.0,
    utility_ibi_max::Real = 1.0e10,
    utility_rebate_per_kw::Real = 0.0,
    utility_rebate_max::Real = 1.0e10,
    production_incentive_per_kwh::Real = 0.0, # Applies to total estimated production, including curtailed energy.
    production_incentive_max_benefit::Real = 1.0e9,
    production_incentive_years::Int = 1,
    production_incentive_max_kw::Real = 1.0e9,
    can_net_meter::Bool = off_grid_flag ? false : true,
    can_wholesale::Bool = off_grid_flag ? false : true,
    can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
    can_curtail::Bool = true,
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.25 : 0.0, # if off grid, 25%, else 0%. Applied to each time_step as a % of PV generation.
    size_class::Union{Int, Nothing} = nothing, # Size class for cost curve selection
    tech_sizes_for_cost_curve::AbstractVector = Float64[], # System sizes for detailed cost curve
    use_detailed_cost_curve::Bool = false, # Use detailed cost curve instead of average cost
    electric_load_annual_kwh::Real = 0.0, # Annual electric load (kWh) for size class determination
    site_land_acres::Union{Real, Nothing} = nothing,  # site.land_acres to determine size_class if space constraineed
    site_roof_squarefeet::Union{Real, Nothing} = nothing  # site.roof_squarefeet to determine size_class if space constraineed
```

!!! note "Multiple PV types" 
    Multiple PV types can be considered by providing an array of PV inputs. See example in `src/test/scenarios/multiple_pvs.json`

!!! note "PV tilt and aziumth"
    If `tilt` is not provided, then it is set to the absolute value of `Site.latitude` for ground-mount systems and is set to 10 degrees for rooftop systems.
    If `azimuth` is not provided, then it is set to 180 if the site is in the northern hemisphere and 0 if in the southern hemisphere.

!!! note "Cost curves and size classes"
When using 'use_detailed_cost_curve' is set to `true`, and providing specific values for `tech_sizes_for_cost_curve` and `installed_cost_per_kw`, both `tech_sizes_for_cost_curve` and `installed_cost_per_kw` must have the same length.
Size class is automatically determined based on average load if not specified, which affects default costs.
Ground-mount('array_type' = 0,2,3,4) systems have different cost structures than rooftop ('array_type' = 1) systems when using default values.

"""
mutable struct PV <: AbstractTech
    tilt
    array_type
    module_type
    losses
    azimuth
    gcr
    radius
    name
    location
    existing_kw
    min_kw
    max_kw
    installed_cost_per_kw
    om_cost_per_kw
    degradation_fraction
    macrs_option_years
    macrs_bonus_fraction
    macrs_itc_reduction
    kw_per_square_foot
    acres_per_kw
    inv_eff
    dc_ac_ratio
    production_factor_series
    federal_itc_fraction
    federal_rebate_per_kw
    state_ibi_fraction
    state_ibi_max
    state_rebate_per_kw
    state_rebate_max
    utility_ibi_fraction
    utility_ibi_max
    utility_rebate_per_kw
    utility_rebate_max
    production_incentive_per_kwh
    production_incentive_max_benefit
    production_incentive_years
    production_incentive_max_kw
    can_net_meter
    can_wholesale
    can_export_beyond_nem_limit
    can_curtail
    operating_reserve_required_fraction
    size_class
    tech_sizes_for_cost_curve
    use_detailed_cost_curve
    electric_load_annual_kwh
    site_land_acres
    site_roof_squarefeet

    function PV(;
        off_grid_flag::Bool = false,
        latitude::Real,
        array_type::Int=1,
        tilt::Real = (array_type == 0 || array_type == 1) ? 20 : 0,
        module_type::Int=0,
        losses::Real=0.14,
        azimuth::Real = latitude≥0 ? 180 : 0,
        gcr::Real=0.4,
        radius::Int=0,
        name::String="PV",
        location::String="both",
        existing_kw::Real=0,
        min_kw::Real=0,
        max_kw::Real=1.0e9,
        installed_cost_per_kw::Union{Real, AbstractVector{<:Real}} = Float64[],
        om_cost_per_kw::Union{Real, AbstractVector{<:Real}} = Float64[],
        degradation_fraction::Real=0.005,
        macrs_option_years::Int = 5,
        macrs_bonus_fraction::Real = 0.6,
        macrs_itc_reduction::Real = 0.5,
        kw_per_square_foot::Real=0.01,
        acres_per_kw::Real=6e-3,
        inv_eff::Real=0.96,
        dc_ac_ratio::Real=1.2,
        production_factor_series::Union{Nothing, Array{<:Real,1}} = nothing,
        federal_itc_fraction::Real = 0.3,
        federal_rebate_per_kw::Real = 0.0,
        state_ibi_fraction::Real = 0.0,
        state_ibi_max::Real = 1.0e10,
        state_rebate_per_kw::Real = 0.0,
        state_rebate_max::Real = 1.0e10,
        utility_ibi_fraction::Real = 0.0,
        utility_ibi_max::Real = 1.0e10,
        utility_rebate_per_kw::Real = 0.0,
        utility_rebate_max::Real = 1.0e10,
        production_incentive_per_kwh::Real = 0.0,
        production_incentive_max_benefit::Real = 1.0e9,
        production_incentive_years::Int = 1,
        production_incentive_max_kw::Real = 1.0e9,
        can_net_meter::Bool = off_grid_flag ? false : true,
        can_wholesale::Bool = off_grid_flag ? false : true,
        can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
        can_curtail::Bool = true,
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.25 : 0.0,
        size_class::Union{Int, Nothing} = nothing,
        tech_sizes_for_cost_curve::AbstractVector = Float64[],
        use_detailed_cost_curve::Bool = false,
        electric_load_annual_kwh::Real = 0.0,
        site_land_acres::Union{Real, Nothing} = nothing,
        site_roof_squarefeet::Union{Real, Nothing} = nothing
        )

        # Adjust operating_reserve_required_fraction based on off_grid_flag
        if !off_grid_flag && !(operating_reserve_required_fraction == 0.0)
            @warn "PV operating_reserve_required_fraction applies only when off_grid_flag is true. Setting operating_reserve_required_fraction to 0.0 for this on-grid analysis."
            operating_reserve_required_fraction = 0.0
        end

        if off_grid_flag && (can_net_meter || can_wholesale || can_export_beyond_nem_limit)
            @warn "Setting PV can_net_meter, can_wholesale, and can_export_beyond_nem_limit to False because `off_grid_flag` is true."
            can_net_meter = false
            can_wholesale = false
            can_export_beyond_nem_limit = false
        end

        # Validate inputs
        invalid_args = String[]
        if !(0 <= azimuth < 360)
            push!(invalid_args, "azimuth must satisfy 0 <= azimuth < 360, got $(azimuth)")
        end
        if !(array_type in [0, 1, 2, 3, 4])
            push!(invalid_args, "array_type must be in [0, 1, 2, 3, 4], got $(array_type)")
        end
        if !(module_type in [0, 1, 2])
            push!(invalid_args, "module_type must be in [0, 1, 2], got $(module_type)")
        end
        if !(0.0 <= losses <= 0.99)
            push!(invalid_args, "losses must satisfy 0.0 <= losses <= 0.99, got $(losses)")
        end
        if !(0 <= tilt <= 90)
            push!(invalid_args, "tilt must satisfy 0 <= tilt <= 90, got $(tilt)")
        end
        if !(location in ["roof", "ground", "both"])
            push!(invalid_args, "location must be in [\"roof\", \"ground\", \"both\"], got $(location)")
        end
        if !(0.0 <= degradation_fraction <= 1.0)
            push!(invalid_args, "degradation_fraction must satisfy 0 <= degradation_fraction <= 1, got $(degradation_fraction)")
        end
        if !(0.0 <= inv_eff <= 1.0)
            push!(invalid_args, "inv_eff must satisfy 0 <= inv_eff <= 1, got $(inv_eff)")
        end
        if !(0.0 <= dc_ac_ratio <= 2.0)
            push!(invalid_args, "dc_ac_ratio must satisfy 0 <= dc_ac_ratio <= 2, got $(dc_ac_ratio)")
        end
        if !isnothing(production_factor_series)
            error_if_series_vals_not_0_to_1(production_factor_series, "PV", "production_factor_series")
        end
        if length(invalid_args) > 0
            throw(ErrorException("Invalid PV argument values: $(invalid_args)"))
        end

        # Get defaults and determine mount type
        defaults = get_pv_defaults_size_class()
        mount_type = array_type in [0, 2, 3, 4] ? "ground" : "roof"

        # Initialize variables needed for processing
        local determined_size_class
        local final_tech_sizes
        local final_installed_cost
        local final_om_cost

        # STEP 1: Determine size class
        determined_size_class = if !isnothing(size_class)
            # User explicitly set size class - validate boundaries
            if size_class < 1
                @warn "Size class $size_class is less than 1, using size class 1 instead"
                1
            elseif size_class > length(defaults)
                @warn "Size class $size_class exceeds maximum ($(length(defaults))), using largest size class instead"
                length(defaults)
            else
                size_class
            end
        elseif typeof(installed_cost_per_kw) <: Real || (installed_cost_per_kw isa AbstractVector && length(installed_cost_per_kw) == 1)
            # Single cost value provided - size class not needed
            size_class
        elseif !isempty(tech_sizes_for_cost_curve) && isempty(installed_cost_per_kw)
            # TODO I'd say just ignore tech_sizes_for_cost_curve in this case, and find default (avg_)installed_cost_per_kw
            # User provided tech sizes but no costs, need size class for costs
            if isnothing(size_class)
                tech_sizes = [c["tech_sizes_for_cost_curve"] for c in defaults]
                get_pv_size_class(
                    electric_load_annual_kwh,
                    tech_sizes,
                    min_kw=min_kw,
                    max_kw=max_kw,
                    existing_kw=existing_kw
                )
            else
                size_class
            end
        elseif !isempty(installed_cost_per_kw)
            # Vector of costs provided
            if isnothing(size_class)
                tech_sizes = [c["tech_sizes_for_cost_curve"] for c in defaults]
                get_pv_size_class(
                    electric_load_annual_kwh,
                    tech_sizes,
                    min_kw=min_kw,
                    max_kw=max_kw,
                    existing_kw=existing_kw
                )
            else
                size_class
            end
        else
            # Default case: Calculate based on land/roof space available or load
            max_kw_for_size_class = max_kw
            max_kw_roof, max_kw_ground = 0.0, 0.0
            space_constrained = false
            if !isnothing(site_roof_squarefeet) && location in ["both", "roof"]
                # Calculate size class based on roof space
                max_kw_roof = kw_per_square_foot * site_roof_squarefeet
                space_constrained = true
            end
            if !isnothing(site_land_acres) && location in ["both", "ground"]
                # Calculate size class based on land space
                max_kw_ground = site_land_acres / acres_per_kw
                space_constrained = true
            end
            if space_constrained
                max_kw_for_size_class = max_kw_roof + max_kw_ground
            end
            tech_sizes = [c["tech_sizes_for_cost_curve"] for c in defaults]
            # Include both roof and land for size class -> cost determination
            get_pv_size_class(
                electric_load_annual_kwh,
                tech_sizes,
                min_kw=min_kw,
                max_kw=max_kw_for_size_class,
                existing_kw=existing_kw,
                space_constrained=space_constrained
            )
        end

        # Get default data for determined size class
        class_defaults = if !isnothing(determined_size_class)            
            matching_default = findfirst(d -> d["size_class"] == determined_size_class, defaults)            
            if isnothing(matching_default)
                throw(ErrorException("Could not find matching defaults for size class $(determined_size_class)"))
            end
            defaults[matching_default]
        end

        # STEP 2: Handle installed costs
        base_installed_cost = if typeof(installed_cost_per_kw) <: Real
            # Single cost value provided by user
            convert(Float64, installed_cost_per_kw)
        elseif installed_cost_per_kw isa AbstractVector && length(installed_cost_per_kw) == 1
            # Single value in vector
            convert(Float64, first(installed_cost_per_kw))
        elseif !isempty(installed_cost_per_kw)
            # Multiple costs provided by user
            convert(Vector{Float64}, installed_cost_per_kw)
        elseif !isnothing(class_defaults)
            # Get from roof data
            if use_detailed_cost_curve && haskey(class_defaults["roof"], "installed_cost_per_kw")
                # Use the detailed cost curve
                convert(Vector{Float64}, class_defaults["roof"]["installed_cost_per_kw"])
            else
                # Use average value or calculate it
                if haskey(class_defaults["roof"], "avg_installed_cost_per_kw")
                    convert(Float64, class_defaults["roof"]["avg_installed_cost_per_kw"])
                else
                    costs = class_defaults["roof"]["installed_cost_per_kw"]
                    sum(costs) / length(costs)
                end
            end
        else
            throw(ErrorException("No installed costs provided and no size class determined"))
        end

        # Apply mount premium if needed
        final_installed_cost = if mount_type != "roof" && 
                                !isnothing(class_defaults) && 
                                haskey(class_defaults, "mount_premiums") &&
                                haskey(class_defaults["mount_premiums"], mount_type) &&
                                haskey(class_defaults["mount_premiums"][mount_type], "cost_premium") &&
                                isempty(installed_cost_per_kw)  # Only apply if user didn't specify
            premium = class_defaults["mount_premiums"][mount_type]["cost_premium"]
            
            if base_installed_cost isa Vector
                [cost * premium for cost in base_installed_cost]
            else
                base_installed_cost * premium
            end
        else
            base_installed_cost
        end

        # STEP 3: Handle tech sizes for cost curve
        final_tech_sizes = if typeof(final_installed_cost) <: Real
            # Single cost value - no tech sizes needed
            Float64[]
        elseif !isempty(tech_sizes_for_cost_curve)
            # User provided tech sizes - check length match
            if final_installed_cost isa Vector && length(tech_sizes_for_cost_curve) != length(final_installed_cost)
                throw(ErrorException("Length mismatch: installed_cost_per_kw ($(length(final_installed_cost))) and tech_sizes_for_cost_curve ($(length(tech_sizes_for_cost_curve))) must match"))
            end
            convert(Vector{Float64}, tech_sizes_for_cost_curve)
        elseif final_installed_cost isa Vector 
            # User provided cost vector but no tech sizes
            if length(final_installed_cost) == 2 && !isnothing(class_defaults)
                # For 2-point cost curves, use size class defaults
                convert(Vector{Float64}, class_defaults["tech_sizes_for_cost_curve"])
            else
                # For other lengths, inform the user
                throw(ErrorException("When providing a $(length(final_installed_cost))-point cost curve, matching tech_sizes_for_cost_curve is required"))
            end
        elseif !isnothing(class_defaults)
            # Use defaults from size class
            convert(Vector{Float64}, class_defaults["tech_sizes_for_cost_curve"])
        else
            Float64[]
        end

        # STEP 4: Handle O&M costs
        base_om_cost = if typeof(om_cost_per_kw) <: Real
            convert(Float64, om_cost_per_kw)
        elseif isempty(om_cost_per_kw) && !isnothing(class_defaults)
            convert(Float64, class_defaults["roof"]["om_cost_per_kw"])
        elseif isempty(om_cost_per_kw)
            18.0  # Default value
        else
            throw(ErrorException("O&M cost must be a single value"))
        end
        
        # Apply O&M premium if needed
        final_om_cost = if mount_type != "roof" && 
                        !isnothing(class_defaults) && 
                        haskey(class_defaults, "mount_premiums") &&
                        haskey(class_defaults["mount_premiums"], mount_type) &&
                        haskey(class_defaults["mount_premiums"][mount_type], "om_premium") &&
                        isempty(om_cost_per_kw)  # Only apply if user didn't specify
            om_premium = class_defaults["mount_premiums"][mount_type]["om_premium"]
            base_om_cost * om_premium
        else
            base_om_cost
        end

        # Update variables with calculated values
        installed_cost_per_kw = final_installed_cost
        om_cost_per_kw = final_om_cost
        size_class = determined_size_class
        tech_sizes_for_cost_curve = final_tech_sizes

        # Instantiate the PV struct
        new(
            tilt,
            array_type,
            module_type,
            losses,
            azimuth,
            gcr,
            radius,
            name,
            location,
            existing_kw,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw, 
            degradation_fraction,
            macrs_option_years,
            macrs_bonus_fraction,
            macrs_itc_reduction,
            kw_per_square_foot,
            acres_per_kw,
            inv_eff,
            dc_ac_ratio,
            production_factor_series,
            federal_itc_fraction,
            federal_rebate_per_kw,
            state_ibi_fraction,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_fraction,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail,
            operating_reserve_required_fraction,
            size_class,
            tech_sizes_for_cost_curve,
            use_detailed_cost_curve,
            electric_load_annual_kwh,
            site_land_acres,
            site_roof_squarefeet
        )
    end
end
# Get a specific PV by name from an array of PVs
function get_pv_by_name(name::String, pvs::AbstractArray{PV, 1})
    pvs[findfirst(pv -> pv.name == name, pvs)]
end

# Load PV default size class data from JSON file
function get_pv_defaults_size_class()
    pv_defaults_path = joinpath(@__DIR__, "..", "..", "data", "pv", "pv_defaults.json")
    if !isfile(pv_defaults_path)
        throw(ErrorException("pv_defaults.json not found at path: $pv_defaults_path"))
    end
    
    pv_defaults_all = JSON.parsefile(pv_defaults_path)
    return pv_defaults_all["size_classes"]
end

# Determine appropriate size class based on system parameters
function get_pv_size_class(electric_load_annual_kwh::Real, tech_sizes_for_cost_curve::AbstractVector;
                          min_kw::Real=0.0, max_kw::Real=1.0e9, existing_kw::Real=0.0, space_constrained=false)
    
    # TODO pass in Site.[land and roof space] to include that in the size class determination

    # Estimate size based on electric load and estimated PV capacity factor
    capacity_factor_estimate = 0.2
    fraction_of_annual_kwh_to_size_pv = 0.5
    size_to_serve_all_load = electric_load_annual_kwh / (8760.0* capacity_factor_estimate)
    effective_size = fraction_of_annual_kwh_to_size_pv * size_to_serve_all_load
    if space_constrained 
        # max_kw was adjusted down based on space available
        effective_size = min(max_kw, size_to_serve_all_load)
    end
    if max_kw != 1.0e9 
        effective_size = min(effective_size, max_kw)
    end
    if min_kw != 0.0
        effective_size = max(effective_size, min_kw)
    end
    
    # Find the appropriate size class for the effective size
    for (i, size_range) in enumerate(tech_sizes_for_cost_curve)
        min_size = convert(Float64, size_range[1])
        max_size = convert(Float64, size_range[2])
        
        if effective_size >= min_size && effective_size <= max_size
            return i
        end
    end
    
    # Handle edge cases
    if effective_size > convert(Float64, tech_sizes_for_cost_curve[end][2])
        return length(tech_sizes_for_cost_curve)
    end
    
    return 1  # Default to smallest size class
end