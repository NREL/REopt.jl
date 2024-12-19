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

    function PV(;
        off_grid_flag::Bool = false,
        latitude::Real,
        array_type::Int=1, # PV Watts array type (0: Ground Mount Fixed (Open Rack); 1: Rooftop, Fixed; 2: Ground Mount 1-Axis Tracking; 3 : Ground Mount 1-Axis Backtracking; 4: Ground Mount, 2-Axis Tracking)
        tilt::Real = (array_type == 0 || array_type == 1) ? 20 : 0, # tilt = 20 for fixed rooftop arrays (1) or ground-mount (2) ; tilt = 0 for everything else (3 and 4)
        module_type::Int=0, # PV module type (0: Standard; 1: Premium; 2: Thin Film)
        losses::Real=0.14,
        azimuth::Real = latitude≥0 ? 180 : 0, # set azimuth to zero for southern hemisphere
        gcr::Real=0.4,
        radius::Int=0, # Radius, in miles, to use when searching for the closest climate data station. Use zero to use the closest station regardless of the distance
        name::String="PV",
        location::String="both",
        existing_kw::Real=0,
        min_kw::Real=0,
        max_kw::Real=1.0e9,
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
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.25 : 0.0, # if off grid, 25%, else 0%. Applied to each time_step as a % of PV generation.
        avg_electric_load_kw::Real = 0.0,
        size_class::Union{Int, Nothing} = nothing # Optional size_class
        )
        @info "Constructing PV with avg_electric_load_kw=$(avg_electric_load_kw), size_class=$(size_class)"
        
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
        # TODO: Validate additional args as needed
    
        if length(invalid_args) > 0
            throw(ErrorException("Invalid PV argument values: $(invalid_args)"))
        end
    
        # Load PV defaults
        @info "Loading PV defaults from pv_defaults.json"
        pv_defaults_path = joinpath(@__DIR__, "..", "..", "data", "pv", "pv_defaults.json")
        if !isfile(pv_defaults_path)
            throw(ErrorException("pv_defaults.json not found at path: $pv_defaults_path"))
        end
        pv_defaults_all = JSON.parsefile(pv_defaults_path)
        @info "PV defaults loaded: $(keys(pv_defaults_all))"
    
        # Determine array_category based on array_type
        if array_type in [0, 2, 3, 4]
            array_category = "pv_groundmount"
        elseif array_type == 1
            array_category = "pv_rooftop"
        else
            throw(ErrorException("Invalid 'array_type': $array_type. Must be one of [0, 1, 2, 3, 4]."))
        end
        # @info "Determined array_category='$array_category' based on array_type=$array_type"
    
        # Extract tech_sizes_for_cost_curve from pv_defaults_all and ensure correct typing
        if haskey(pv_defaults_all[array_category], "tech_sizes_for_cost_curve")
            raw_tech_sizes = pv_defaults_all[array_category]["tech_sizes_for_cost_curve"]
            # Convert each sub-array to Vector{Float64}
            tech_sizes_for_cost_curve = [Float64.(size_range) for size_range in raw_tech_sizes]
            @info "Extracted and converted tech_sizes_for_cost_curve: $(tech_sizes_for_cost_curve)"
        else
            throw(ErrorException("Missing 'tech_sizes_for_cost_curve' for array_category '$array_category' in pv_defaults.json"))
        end
    
        # Determine size_class
        if isnothing(size_class)
            size_class = get_pv_size_class(avg_electric_load_kw, tech_sizes_for_cost_curve)
            @info "Determined size_class=$size_class based on avg_electric_load_kw=$avg_electric_load_kw"
        else
            # Validate provided size_class
            num_size_classes = length(pv_defaults_all[array_category]["installed_cost_per_kw"])
            if size_class < 0 || size_class >= num_size_classes
                throw(ErrorException("Invalid size_class: $size_class. Must be between 0 and $(num_size_classes - 1)."))
            end
            @info "Using provided size_class=$size_class"
        end
    
        # Extract and convert installed_cost_per_kw and om_cost_per_kw
        if haskey(pv_defaults_all[array_category], "installed_cost_per_kw")
            raw_installed_cost = pv_defaults_all[array_category]["installed_cost_per_kw"]
            # Convert each sub-array to Vector{Float64}
            installed_cost_list = [Float64.(entry) for entry in raw_installed_cost]
            @info "Extracted and converted installed_cost_per_kw: $(installed_cost_list)"
        else
            throw(ErrorException("Missing 'installed_cost_per_kw' for array_category '$array_category' in pv_defaults.json"))
        end
    
        if haskey(pv_defaults_all[array_category], "om_cost_per_kw")
            raw_om_cost = pv_defaults_all[array_category]["om_cost_per_kw"]
            # Convert to Vector{Float64}
            om_cost_list = Float64.(raw_om_cost)
            @info "Extracted and converted om_cost_per_kw: $(om_cost_list)"
        else
            throw(ErrorException("Missing 'om_cost_per_kw' for array_category '$array_category' in pv_defaults.json"))
        end
    
        # Apply size_class-specific defaults
        installed_cost_per_kw = get_installed_cost_per_kw(installed_cost_list, size_class)
        om_cost_per_kw = get_om_cost_per_kw(om_cost_list, size_class)
        @info "Set installed_cost_per_kw=$installed_cost_per_kw and om_cost_per_kw=$om_cost_per_kw based on size_class=$size_class"
    
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
            size_class 
        )
    end
end

function get_pv_by_name(name::String, pvs::AbstractArray{PV, 1})
    pvs[findfirst(pv -> pv.name == name, pvs)]
end

# Helper Function: get_pv_size_class
"""
    get_pv_size_class(avg_electric_load_kw::Real, tech_sizes_for_cost_curve::Vector{Vector{Float64}})

Determines the size_class based on average electric load and the technology size curve.
"""
function get_pv_size_class(avg_electric_load_kw::Real, tech_sizes_for_cost_curve::Vector{Vector{Float64}})
    size_class = 0
    for (i, size_range) in enumerate(tech_sizes_for_cost_curve)
        lower_bound, upper_bound = size_range
        if avg_electric_load_kw >= lower_bound && avg_electric_load_kw < upper_bound
            size_class = i - 1  # Zero-indexed
            break
        end
    end
    # If above all defined ranges, assign to the highest size_class
    if avg_electric_load_kw >= tech_sizes_for_cost_curve[end][2]
        size_class = length(tech_sizes_for_cost_curve)
    end
    return size_class
end

# Helper Function: get_installed_cost_per_kw
"""
    get_installed_cost_per_kw(installed_cost_list::Vector{Vector{Float64}}, size_class::Int)

Retrieves the installed cost per kW based on the size_class using the installed_cost_per_kw list from pv_defaults.json.
"""
function get_installed_cost_per_kw(installed_cost_list::Vector{Vector{Float64}}, size_class::Int)
    if size_class < 0 || size_class >= length(installed_cost_list)
        throw(ErrorException("Size class $size_class is out of bounds for installed_cost_per_kw."))
    end
    # Assuming the list is ordered by size_class, and each entry is [size, cost]
    return installed_cost_list[size_class + 1][2]
end

# Helper Function: get_om_cost_per_kw
"""
    get_om_cost_per_kw(om_cost_list::Vector{Float64}, size_class::Int)

Retrieves the O&M cost per kW based on the size_class using the om_cost_per_kw list from pv_defaults.json.
"""
function get_om_cost_per_kw(om_cost_list::Vector{Float64}, size_class::Int)
    if size_class < 0 || size_class >= length(om_cost_list)
        throw(ErrorException("Size class $size_class is out of bounds for om_cost_per_kw."))
    end
    return om_cost_list[size_class + 1]
end
