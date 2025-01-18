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
    production_incentive_per_kwh::Real = 0.0,
    production_incentive_max_benefit::Real = 1.0e9,
    production_incentive_years::Int = 1,
    production_incentive_max_kw::Real = 1.0e9,
    can_net_meter::Bool = off_grid_flag ? false : true,
    can_wholesale::Bool = off_grid_flag ? false : true,
    can_export_beyond_nem_limit::Bool = off_grid_flag ? false : true,
    can_curtail::Bool = true,
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.25 : 0.0, # if off grid, 25%, else 0%. Applied to each time_step as a % of PV generation.
```

!!! note "Multiple PV types" 
    Multiple PV types can be considered by providing an array of PV inputs. See example in `src/test/scenarios/multiple_pvs.json`

!!! note "PV tilt and aziumth"
    If `tilt` is not provided, then it is set to the absolute value of `Site.latitude` for ground-mount systems and is set to 10 degrees for rooftop systems.
    If `azimuth` is not provided, then it is set to 180 if the site is in the northern hemisphere and 0 if in the southern hemisphere.

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
    avg_electric_load_kw

    function PV(;
        off_grid_flag::Bool = false,
        latitude::Real,
        avg_electric_load_kw::Real = 0.0,
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
        installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = Float64[],
        om_cost_per_kw::Union{Float64, AbstractVector{Float64}} = Float64[],
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
        tech_sizes_for_cost_curve::AbstractVector = Float64[]
        )
        @info "PV Constructor - Initial values:" avg_electric_load_kw array_type size_class

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

        if length(invalid_args) > 0
            throw(ErrorException("Invalid PV argument values: $(invalid_args)"))
        end
        @info "Before getting defaults:" avg_electric_load_kw array_type

        # Get defaults structure
        pv_defaults_all = get_pv_defaults_size_class(array_type=array_type, avg_electric_load_kw=avg_electric_load_kw)
        array_category = array_type in [0, 2, 3, 4] ? "ground" : "roof" 
        defaults = pv_defaults_all[array_category]["size_classes"]

        # Initialize variables we'll need
        local determined_size_class
        local final_tech_sizes
        local final_installed_cost
        local final_om_cost

        # STEP 1: Determine size class
        determined_size_class = if !isnothing(size_class)
            # Case 1: User explicitly set size class
            if size_class < 1
                @warn "Size class $size_class is less than 1, using size class 1 instead"
                1
            elseif size_class > length(defaults)
                @warn "Size class $size_class is greater than maximum available ($(length(defaults))), using largest size class $(length(defaults)) instead"
                length(defaults)
            else
                @info "Using explicitly provided size class: $size_class"
                size_class
            end

        elseif typeof(installed_cost_per_kw) <: Number || (installed_cost_per_kw isa AbstractVector && length(installed_cost_per_kw) == 1)
            # Case 2: Single cost value provided - size class not needed
            @info "Single cost value provided, size class not needed"
            size_class
        elseif !isempty(tech_sizes_for_cost_curve) && isempty(installed_cost_per_kw)
            # Case 4: User provided tech curves but no costs, need size class for installed costs
            if isnothing(size_class)
                get_pv_size_class(
                    avg_electric_load_kw,
                    [c["tech_sizes_for_cost_curve"] for c in defaults],
                    min_kw=min_kw,
                    max_kw=max_kw,
                    existing_kw=existing_kw
                )
            else
                size_class
            end
        elseif !isempty(installed_cost_per_kw)
            # Case 3: Vector of costs provided
            if isnothing(size_class)
                get_pv_size_class(
                    avg_electric_load_kw,
                    [c["tech_sizes_for_cost_curve"] for c in defaults],
                    min_kw=min_kw,
                    max_kw=max_kw,
                    existing_kw=existing_kw
                )
            else
                size_class
            end
        else
            # Default case: Calculate based on average load
            get_pv_size_class(
                avg_electric_load_kw,
                [c["tech_sizes_for_cost_curve"] for c in defaults],
                min_kw=min_kw,
                max_kw=max_kw,
                existing_kw=existing_kw
            )
        end

        class_defaults = if !isnothing(determined_size_class)            
            # Julia is 1-based indexed but we want to match the size_class numbers
            matching_default = findfirst(d -> d["size_class"] == determined_size_class, defaults)            
            if isnothing(matching_default)
                throw(ErrorException("Could not find matching defaults for size class $(determined_size_class)"))
            end
            defaults[matching_default]
        end

        # STEP 2: Handle installed costs
        final_installed_cost = if typeof(installed_cost_per_kw) <: Number
            # Single cost value provided
            convert(Float64, installed_cost_per_kw)
        elseif installed_cost_per_kw isa AbstractVector && length(installed_cost_per_kw) == 1
            # Single value in vector
            convert(Float64, first(installed_cost_per_kw))
        elseif !isempty(installed_cost_per_kw)
            # Multiple costs provided
            convert(Vector{Float64}, installed_cost_per_kw)
        elseif !isnothing(class_defaults)
            # Use defaults from size class
            convert(Vector{Float64}, class_defaults["installed_cost_per_kw"])
        else
            throw(ErrorException("No installed costs provided and no size class determined"))
        end

        # STEP 3: Handle tech sizes
        final_tech_sizes = if typeof(final_installed_cost) <: Number
            # Single cost value - no tech sizes needed
            Float64[]
        elseif !isempty(tech_sizes_for_cost_curve)
            # User provided tech sizes
            if final_installed_cost isa Vector && length(tech_sizes_for_cost_curve) != length(final_installed_cost)
                throw(ErrorException("Length mismatch: installed_cost_per_kw and tech_sizes_for_cost_curve"))
            end
            convert(Vector{Float64}, tech_sizes_for_cost_curve)
        elseif !isnothing(class_defaults)
            # Use defaults from size class
            convert(Vector{Float64}, class_defaults["tech_sizes_for_cost_curve"])
        else
            Float64[]
        end

        # STEP 4: Handle O&M costs
        final_om_cost = if typeof(om_cost_per_kw) <: Number
            convert(Float64, om_cost_per_kw)
        elseif isempty(om_cost_per_kw) && !isnothing(class_defaults)
            convert(Float64, class_defaults["om_cost_per_kw"])
        elseif isempty(om_cost_per_kw)
            18.0  # Default value from REopt Webtool
        else
            throw(ErrorException("O&M cost must be a single value"))
        end
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
            avg_electric_load_kw 
        )
    end
end

function get_pv_by_name(name::String, pvs::AbstractArray{PV, 1})
    pvs[findfirst(pv -> pv.name == name, pvs)]
end

# Helper function 

function get_pv_defaults_size_class(; array_type::Int = 1, avg_electric_load_kw::Real = 0.0)
    @info "get_pv_defaults_size_class called with:" array_type avg_electric_load_kw

    pv_defaults_path = joinpath(@__DIR__, "..", "..", "data", "pv", "pv_defaults.json")
    if !isfile(pv_defaults_path)
        throw(ErrorException("pv_defaults.json not found at path: $pv_defaults_path"))
    end
    
    # Parse JSON once
    pv_defaults_all = JSON.parsefile(pv_defaults_path)
    
    # Return full defaults structure
    return pv_defaults_all
end


function get_pv_size_class(avg_electric_load_kw::Real, tech_sizes_for_cost_curve::AbstractVector;
                          min_kw::Real=0.0, max_kw::Real=1.0e9, existing_kw::Real=0.0)
    # Adjust max_kw to account for existing capacity
    @info "get_pv_size_class called with:" avg_electric_load_kw min_kw max_kw existing_kw

    adjusted_max_kw = max_kw - existing_kw
    
    effective_size = if max_kw != 1.0e9 
        min(avg_electric_load_kw, adjusted_max_kw)
    else
        avg_electric_load_kw
    end
    
    effective_size = if min_kw != 0.0
        max(effective_size, min_kw)
    else
        effective_size
    end

    @info "Determining size class for effective size: $effective_size"
    
    for (i, size_range) in enumerate(tech_sizes_for_cost_curve)
        min_size = convert(Float64, size_range[1])
        max_size = convert(Float64, size_range[2])
        
        if effective_size >= min_size && effective_size <= max_size
            @info "Found matching size class: $i"
            return i  # Size classes now start at 1
        end
    end
    
    # Handle sizes above the largest range
    if effective_size > convert(Float64, tech_sizes_for_cost_curve[end][2])
        size_class = length(tech_sizes_for_cost_curve)
        @info "Size exceeds maximum range, using largest class: $size_class"
        return size_class
    end
    
    @info "No matching range found, using default class: 1"
    return 1
end