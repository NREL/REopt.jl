# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
Load Alignment Module for REopt.jl

This module provides functionality to align load time series from different source years to a common
reference year while preserving critical temporal patterns and energy totals.

# Key Features
- **Multi-resolution support**: Handles hourly, 30-minute, 15-minute, and 5-minute time steps
- **Weekday alignment**: Ensures weekdays in source data map to weekdays in target year (critical for TOU rates)
- **Energy conservation**: Preserves total and monthly energy consumption
- **Leap year handling**: Flexible policies for normalizing leap year data

# Typical Use Cases
1. **Multiple load components**: Combine site load, EV charging, and other loads from different years
2. **Historical data**: Use historical load data aligned to current/future rate structures
3. **Time-of-Use rates**: Ensure proper weekday/weekend pattern alignment for TOU optimization

# Algorithm Overview
1. Normalize all loads to regular year length (365 days) handling leap years
2. Calculate day-of-week shift between source and target years
3. Rotate load values by the shift amount (preserving daily patterns)
4. Apply monthly scaling to preserve original monthly energy distribution
```
"""

using Dates
using Statistics

"""
    AlignmentMetadata

Stores metadata about the alignment operation for debugging and validation.

# Fields
- `source_year::Int`: Original year of the load data
- `target_year::Int`: Target year to align to
- `method::String`: Alignment method used (e.g., "weekday_rotation")
- `shift_days::Int`: Number of days shifted to align weekdays
- `preserve_monthly::Bool`: Whether monthly energy was preserved
- `leap_policy::String`: How leap years were handled
- `notes::String`: Additional notes about the alignment
- `energy_error::Float64`: Relative error in total energy (should be < 0.0001%)
"""
struct AlignmentMetadata
    source_year::Int
    target_year::Int
    method::String
    shift_days::Int
    preserve_monthly::Bool
    leap_policy::String
    notes::String
    energy_error::Float64
end

"""
    normalize_to_regular_year(loads_kw::Vector{<:Real}, year::Int, time_steps_per_hour::Int; leap_policy::String = "truncate_dec31")

Normalize a load series to a regular (non-leap) year with 8760 hours worth of data, 
handling leap years according to the specified policy.


# Arguments
- `loads_kw::Vector{<:Real}`: Load values at specified time resolution
- `year::Int`: The year of the load data
- `time_steps_per_hour::Int`: Number of time steps per hour (1 for hourly, 2 for 30-min, 4 for 15-min, 12 for 5-min)
- `leap_policy::String`: How to handle leap years
  - "truncate_dec31": Remove last 24 hours of Dec 31 (REopt legacy behavior)
  - "drop_feb29": Remove Feb 29 to preserve end-of-year alignment

# Returns
- `Vector{Float64}`: Normalized load series with regular year length (8760 * time_steps_per_hour elements)

# Throws
- `ArgumentError`: If the input length cannot be normalized
"""
function normalize_to_regular_year(loads_kw::Vector{<:Real}, year::Int, time_steps_per_hour::Int = 1; 
                                   leap_policy::String = "truncate_dec31")::Vector{Float64}
    loads = Float64.(loads_kw)
    n = length(loads)
    
    # Calculate expected lengths for regular (365 days) and leap (366 days) years
    hours_per_regular_year = 8760
    hours_per_leap_year = 8784
    expected_regular = hours_per_regular_year * time_steps_per_hour
    expected_leap = hours_per_leap_year * time_steps_per_hour
    
    # If already correct length for regular year
    if n == expected_regular
        return loads
    end
    
    # Handle leap year data
    if n == expected_leap && Dates.isleapyear(year)
        steps_per_day = 24 * time_steps_per_hour
        
        if leap_policy == "truncate_dec31"
            # Remove last day (Dec 31)
            return loads[1:expected_regular]
            
        elseif leap_policy == "drop_feb29"
            # Remove Feb 29 to preserve year-end alignment
            # Jan (31 days) + Feb 1-28 (28 days) = 59 days
            days_before_feb29 = 31 + 28
            feb29_start = (days_before_feb29 * steps_per_day) + 1
            feb29_end = feb29_start + steps_per_day - 1
            return vcat(loads[1:feb29_start-1], loads[feb29_end+1:end])
            
        else
            throw(ArgumentError("Unknown leap_policy: $leap_policy. Must be 'truncate_dec31' or 'drop_feb29'"))
        end
    end
    
    # Error: unexpected length
    throw(ArgumentError(
        "Cannot normalize load series of length $n for year $year with time_steps_per_hour=$time_steps_per_hour. " *
        "Expected $expected_regular (regular year) or $expected_leap (leap year)."
    ))
end

"""
    calculate_weekday_shift(source_year::Int, target_year::Int)

Calculate the number of days to shift to align weekdays between source and target years.

# Arguments
- `source_year::Int`: Source year of the data
- `target_year::Int`: Target year to align to

# Returns
- `Int`: Number of days to shift (0-6)
"""
function calculate_weekday_shift(source_year::Int, target_year::Int)::Int
    source_jan1 = Date(source_year, 1, 1)
    target_jan1 = Date(target_year, 1, 1)
    
    # dayofweek: Monday=1, Tuesday=2, ..., Sunday=7
    dow_source = Dates.dayofweek(source_jan1)
    dow_target = Dates.dayofweek(target_jan1)
    
    # Calculate shift needed to align weekdays
    shift = mod(dow_target - dow_source, 7)
    
    return shift
end

"""
    apply_monthly_scaling!(aligned_loads::Vector{Float64}, original_loads::Vector{Float64}, 
                          source_year::Int, target_year::Int, time_steps_per_hour::Int = 1)

Apply monthly energy scaling to preserve monthly totals after rotation.

This function modifies `aligned_loads` in-place to match the monthly energy distribution
of `original_loads` while maintaining the temporal patterns from the rotation.

The rotation process shifts daily blocks to align weekdays, which can cause slight shifts
in monthly boundaries. This function corrects for that by scaling each month to match
the original monthly energy total.

# Arguments
- `aligned_loads::Vector{Float64}`: Rotated load series to be scaled (modified in-place)
- `original_loads::Vector{Float64}`: Original load series with desired monthly totals
- `source_year::Int`: Year of the original loads
- `target_year::Int`: Year of the aligned loads
- `time_steps_per_hour::Int`: Time resolution (1=hourly, 2=30-min, 4=15-min, 12=5-min)
"""
function apply_monthly_scaling!(aligned_loads::Vector{Float64}, original_loads::Vector{Float64}, 
                                source_year::Int, target_year::Int, time_steps_per_hour::Int = 1)
    steps_per_day = 24 * time_steps_per_hour
    
    # Calculate monthly totals for source (original loads)
    source_monthly_totals = zeros(12)
    step_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(source_year, month, 1))
        steps_in_month = days_in_month * steps_per_day
        month_end = min(step_idx + steps_in_month - 1, length(original_loads))
        source_monthly_totals[month] = sum(original_loads[step_idx:month_end])
        step_idx = month_end + 1
    end
    
    # Calculate monthly totals for target (before scaling)
    target_monthly_totals = zeros(12)
    step_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(target_year, month, 1))
        steps_in_month = days_in_month * steps_per_day
        month_end = min(step_idx + steps_in_month - 1, length(aligned_loads))
        target_monthly_totals[month] = sum(aligned_loads[step_idx:month_end])
        step_idx = month_end + 1
    end
    
    # Apply scaling factors month by month
    step_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(target_year, month, 1))
        steps_in_month = days_in_month * steps_per_day
        month_end = min(step_idx + steps_in_month - 1, length(aligned_loads))
        
        # Calculate scale factor (avoid division by zero)
        scale_factor = if target_monthly_totals[month] > 0
            source_monthly_totals[month] / target_monthly_totals[month]
        else
            1.0
        end
        
        # Apply scaling to this month's time steps
        aligned_loads[step_idx:month_end] .*= scale_factor
        
        step_idx = month_end + 1
    end
end

"""
    align_series_to_year(loads_kw::Vector{<:Real}, source_year::Int, target_year::Int;
                        time_steps_per_hour::Int = 1,
                        method::String = "weekday_rotation",
                        preserve_monthly::Bool = true,
                        leap_policy::String = "truncate_dec31")

Align a load time series from its source year to a target year while preserving weekday patterns.

This is the core alignment function that implements the weekday rotation algorithm.
It ensures that weekdays in the source data map to weekdays in the target year,
which is critical for proper TOU rate application.

# Arguments
- `loads_kw::Vector{<:Real}`: Load values from source year (any time resolution)
- `source_year::Int`: Year of the source data
- `target_year::Int`: Year to align to
- `time_steps_per_hour::Int`: Time resolution (1=hourly, 2=30-min, 4=15-min, 12=5-min)
- `method::String`: Alignment method ("weekday_rotation" or "none")
- `preserve_monthly::Bool`: Whether to preserve monthly energy totals (default: true)
- `leap_policy::String`: How to handle leap years (default: "truncate_dec31")

# Returns
- `Tuple{Vector{Float64}, AlignmentMetadata}`: Aligned loads and metadata

# Check alignment quality
@assert metadata.energy_error < 0.0001  # Less than 0.0001% error
println("Shifted by \$(metadata.shift_days) days")
```
"""
function align_series_to_year(loads_kw::Vector{<:Real}, source_year::Int, target_year::Int;
                             time_steps_per_hour::Int = 1,
                             method::String = "weekday_rotation",
                             preserve_monthly::Bool = true,
                             leap_policy::String = "truncate_dec31")::Tuple{Vector{Float64}, AlignmentMetadata}
    
    # Step 1: Normalize to regular year (365 days) handling leap years if needed
    normalized_loads = normalize_to_regular_year(loads_kw, source_year, time_steps_per_hour; leap_policy=leap_policy)
    original_energy = sum(normalized_loads)
    
    # Early return: Same year or no alignment requested
    if source_year == target_year || method == "none"
        reason = source_year == target_year ? "No change - same year" : "No alignment performed"
        metadata = AlignmentMetadata(
            source_year, target_year, method, 0, preserve_monthly, leap_policy, reason, 0.0
        )
        return (normalized_loads, metadata)
    end
    
    # Validate alignment method
    if method != "weekday_rotation"
        throw(ArgumentError("Unknown alignment method: $method. Must be 'weekday_rotation' or 'none'"))
    end
    
    # Step 2: Calculate shift needed to align weekdays
    shift_days = calculate_weekday_shift(source_year, target_year)
    
    # Early return: Weekdays already aligned
    if shift_days == 0
        final_energy = sum(normalized_loads)
        energy_error_pct = abs(final_energy - original_energy) / original_energy * 100.0
        metadata = AlignmentMetadata(
            source_year, target_year, method, 0, preserve_monthly, leap_policy,
            "Weekdays already aligned", energy_error_pct
        )
        return (normalized_loads, metadata)
    end
    
    # Step 3: Rotate loads by shifting daily blocks and replicate first day at the end
    steps_per_day = 24 * time_steps_per_hour
    shift_steps = shift_days * steps_per_day
    # Rotate: take everything from shift_steps+1 to end, then append the first day (not the shifted-out days)
    # This ensures the last day matches the first day after rotation
    rotated_loads = vcat(normalized_loads[shift_steps+1:end], normalized_loads[shift_steps+1:shift_steps+steps_per_day])
    
    # Re-normalize to preserve exact annual energy (rotated profile is 8760 + 24 = 8784 hours)
    # We need to scale back down so the sum equals the original_energy
    current_sum = sum(rotated_loads)
    if current_sum > 0
        rotated_loads = rotated_loads .* (original_energy / current_sum)
    end
    
    # Step 4: Apply monthly scaling if requested (preserves original monthly energy)
    if preserve_monthly
        apply_monthly_scaling!(rotated_loads, normalized_loads, source_year, target_year, time_steps_per_hour)
        notes = "Rotated $shift_days days; monthly energy preserved; leap_policy=$leap_policy"
    else
        notes = "Rotated $shift_days days; leap_policy=$leap_policy"
    end
    
    # Calculate final energy error
    final_energy = sum(rotated_loads)
    energy_error_pct = abs(final_energy - original_energy) / original_energy * 100.0
    
    metadata = AlignmentMetadata(
        source_year, target_year, method, shift_days, preserve_monthly, leap_policy,
        notes, energy_error_pct
    )
    
    return (rotated_loads, metadata)
end

"""
    select_reference_year(current_year::Int; 
                         user_selected::Union{Int, Nothing} = nothing,
                         allow_future::Bool = true,
                         max_future_delta::Int = 10)

Select an appropriate reference year for load alignment.

# Arguments
- `current_year::Int`: Current calendar year
- `user_selected::Union{Int, Nothing}`: User-specified year (overrides automatic selection)
- `allow_future::Bool`: Whether to allow future years (default: true)
- `max_future_delta::Int`: Maximum years into the future allowed (default: 10)

# Returns
- `Int`: Selected reference year
"""
function select_reference_year(current_year::Int; 
                              user_selected::Union{Int, Nothing} = nothing,
                              allow_future::Bool = true,
                              max_future_delta::Int = 10)::Int
    
    # If user specified, validate and return
    if user_selected !== nothing
        if !allow_future && user_selected > current_year
            throw(ArgumentError("Future years not allowed, but $user_selected > $current_year"))
        end
        
        if allow_future && (user_selected > current_year + max_future_delta)
            throw(ArgumentError("Selected year $user_selected is too far in the future (max: $(current_year + max_future_delta))"))
        end
        
        if user_selected < 1900
            throw(ArgumentError("Selected year $user_selected is too far in the past"))
        end
        
        return user_selected
    end
    
    # Default: use current year
    return current_year
end

"""
    align_multiple_loads_to_reference_year(load_components::Dict{String, Dict{String, Any}},
                                          reference_year::Int;
                                          time_steps_per_hour::Int = 1,
                                          preserve_monthly::Bool = true,
                                          leap_policy::String = "truncate_dec31")

Align multiple load components from different source years to a reference year.

This function coordinates the alignment of multiple load components (e.g., site load,
EV load, industrial load) from potentially different source years to a single reference
year. All components are aligned and then summed to create a total load profile.

# Arguments
- `load_components::Dict{String, Dict{String, Any}}`: Dictionary of load components where each component has:
  - "loads_kw": Vector of load values (any time resolution)
  - "year": Source year of the data
- `reference_year::Int`: Target year to align all loads to
- `time_steps_per_hour::Int`: Time resolution (1=hourly, 2=30-min, 4=15-min, 12=5-min)
- `preserve_monthly::Bool`: Whether to preserve monthly energy (default: true)
- `leap_policy::String`: How to handle leap years (default: "truncate_dec31")

# Returns
- `Tuple{Vector{Float64}, Dict{String, Vector{Float64}}, Dict{String, Any}}`:
  - Total combined load (8760 * time_steps_per_hour time steps)
  - Dictionary of individual aligned component loads
  - Metadata dictionary with alignment information for each component
"""
function align_multiple_loads_to_reference_year(load_components::Dict{String, <:Any},
                                               reference_year::Int;
                                               time_steps_per_hour::Int = 1,
                                               preserve_monthly::Bool = true,
                                               leap_policy::String = "truncate_dec31")::Tuple{Vector{Float64}, Dict{String, Vector{Float64}}, Dict{String, Any}}
    
    if isempty(load_components)
        throw(ArgumentError("load_components dictionary is empty"))
    end
    
    # Initialize storage
    aligned_components = Dict{String, Vector{Float64}}()
    metadata_dict = Dict{String, Any}()
    
    # Align each component
    for (component_name, component_data) in load_components
        # Validate component data
        if !haskey(component_data, "loads_kw")
            throw(ArgumentError("Component '$component_name' missing 'loads_kw' field"))
        end
        if !haskey(component_data, "year")
            throw(ArgumentError("Component '$component_name' missing 'year' field"))
        end
        
        loads = component_data["loads_kw"]
        source_year = component_data["year"]
        
        # Align this component
        aligned_loads, alignment_metadata = align_series_to_year(
            loads, source_year, reference_year;
            time_steps_per_hour=time_steps_per_hour,
            method="weekday_rotation",
            preserve_monthly=preserve_monthly,
            leap_policy=leap_policy
        )
        
        # Store results
        aligned_components[component_name] = aligned_loads
        
        # Store metadata
        metadata_dict[component_name] = Dict(
            "original_year" => alignment_metadata.source_year,
            "target_year" => alignment_metadata.target_year,
            "shift_days" => alignment_metadata.shift_days,
            "energy_error_percent" => alignment_metadata.energy_error,
            "method" => alignment_metadata.method,
            "preserve_monthly" => alignment_metadata.preserve_monthly,
            "leap_policy" => alignment_metadata.leap_policy,
            "notes" => alignment_metadata.notes,
            "original_annual_kwh" => sum(loads),
            "aligned_annual_kwh" => sum(aligned_loads)
        )
    end
    
    # Sum all aligned components to get total load
    total_load = sum(values(aligned_components))
    
    # Add summary metadata
    metadata_dict["_summary"] = Dict(
        "reference_year" => reference_year,
        "total_components" => length(load_components),
        "total_annual_kwh" => sum(total_load),
        "component_names" => collect(keys(load_components)),
        "leap_policy" => leap_policy,
        "preserve_monthly" => preserve_monthly,
        "time_steps_per_hour" => time_steps_per_hour
    )
    
    return (total_load, aligned_components, metadata_dict)
end

# Export public API functions
export align_series_to_year
export align_multiple_loads_to_reference_year
export select_reference_year
export normalize_to_regular_year
export AlignmentMetadata
