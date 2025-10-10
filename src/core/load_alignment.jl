# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
Load Alignment Module for REopt.jl

This module provides functionality to align load time series from different source years to a reference
target year while preserving:
- Weekday/weekend patterns (critical for TOU rate alignment)
- Total energy consumption
- Monthly energy distributions

Algorithm Overview:
1. Normalize all loads to 8760 hours (handle leap years)
2. Calculate day-of-week shift between source and target years
3. Rotate hourly values by the shift amount (in 24-hour blocks)
4. Apply monthly scaling to preserve original monthly energy totals

This ensures that weekdays in the source data align with weekdays in the target year,
which is essential for proper time-of-use (TOU) rate application.
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
    normalize_to_8760(loads_kw::Vector{<:Real}, year::Int; leap_policy::String = "truncate_dec31")

Normalize a load series to exactly 8760 hours, handling leap years according to the specified policy.

# Arguments
- `loads_kw::Vector{<:Real}`: Hourly load values
- `year::Int`: The year of the load data
- `leap_policy::String`: How to handle leap years
  - "truncate_dec31": Remove last 24 hours of Dec 31 (REopt legacy behavior)
  - "drop_feb29": Remove Feb 29 to preserve end-of-year alignment

# Returns
- `Vector{Float64}`: Normalized 8760-hour load series

# Throws
- `ArgumentError`: If the input length cannot be normalized to 8760 hours
"""
function normalize_to_8760(loads_kw::Vector{<:Real}, year::Int; leap_policy::String = "truncate_dec31")::Vector{Float64}
    loads = Float64.(loads_kw)
    n = length(loads)
    
    # If already 8760, return as-is
    if n == 8760
        return loads
    end
    
    # Handle leap year (8784 hours)
    if n == 8784 && Dates.isleapyear(year)
        if leap_policy == "truncate_dec31"
            # Remove last 24 hours (Dec 31)
            return loads[1:8760]
        elseif leap_policy == "drop_feb29"
            # Remove Feb 29 (24 hours starting at hour 1417 = (31 + 28) * 24 + 1)
            # Jan = 31 days = 744 hours (1-744)
            # Feb 1-28 = 28 days = 672 hours (745-1416)
            # Feb 29 = 24 hours (1417-1440)
            feb29_start = (31 + 28) * 24 + 1  # Hour index for Feb 29 00:00
            return vcat(loads[1:feb29_start-1], loads[feb29_start+24:end])
        else
            throw(ArgumentError("Unknown leap_policy: $leap_policy. Must be 'truncate_dec31' or 'drop_feb29'"))
        end
    end
    
    throw(ArgumentError("Cannot normalize load series of length $n for year $year to 8760 hours"))
end

"""
    calculate_weekday_shift(source_year::Int, target_year::Int)

Calculate the number of days to shift to align weekdays between source and target years.

# Arguments
- `source_year::Int`: Source year of the data
- `target_year::Int`: Target year to align to

# Returns
- `Int`: Number of days to shift (0-6)

# Example
```julia
# If source year starts on Friday and target starts on Monday
shift = calculate_weekday_shift(2016, 2024)  # Returns 3 days
```
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
    apply_monthly_scaling!(loads_kw::Vector{Float64}, original_loads::Vector{Float64}, 
                          source_year::Int, target_year::Int)

Apply monthly scaling to preserve original monthly energy totals after rotation.

This function modifies `loads_kw` in-place to match the monthly energy distribution
of `original_loads` while maintaining the temporal patterns from the rotation.

# Arguments
- `loads_kw::Vector{Float64}`: Aligned load series to be scaled (modified in-place)
- `original_loads::Vector{Float64}`: Original load series with desired monthly totals
- `source_year::Int`: Year of the original loads
- `target_year::Int`: Year of the aligned loads
"""
function apply_monthly_scaling!(loads_kw::Vector{Float64}, original_loads::Vector{Float64}, 
                                source_year::Int, target_year::Int)
    # Calculate monthly totals for source
    source_monthly = zeros(12)
    hour_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(source_year, month, 1))
        hours_in_month = days_in_month * 24
        month_end = min(hour_idx + hours_in_month - 1, length(original_loads))
        source_monthly[month] = sum(original_loads[hour_idx:month_end])
        hour_idx = month_end + 1
    end
    
    # Calculate monthly totals for target (before scaling)
    target_monthly = zeros(12)
    hour_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(target_year, month, 1))
        hours_in_month = days_in_month * 24
        month_end = min(hour_idx + hours_in_month - 1, length(loads_kw))
        target_monthly[month] = sum(loads_kw[hour_idx:month_end])
        hour_idx = month_end + 1
    end
    
    # Apply scaling factors month by month
    hour_idx = 1
    for month in 1:12
        days_in_month = Dates.daysinmonth(Date(target_year, month, 1))
        hours_in_month = days_in_month * 24
        month_end = min(hour_idx + hours_in_month - 1, length(loads_kw))
        
        # Calculate scale factor (avoid division by zero)
        scale_factor = target_monthly[month] > 0 ? source_monthly[month] / target_monthly[month] : 1.0
        
        # Apply scaling to this month's hours
        loads_kw[hour_idx:month_end] .*= scale_factor
        
        hour_idx = month_end + 1
    end
end

"""
    align_series_to_year(loads_kw::Vector{<:Real}, source_year::Int, target_year::Int;
                        method::String = "weekday_rotation",
                        preserve_monthly::Bool = true,
                        leap_policy::String = "truncate_dec31")

Align a load time series from its source year to a target year while preserving weekday patterns.

This is the core alignment function that implements the weekday rotation algorithm.
It ensures that weekdays in the source data map to weekdays in the target year,
which is critical for proper TOU rate application.

# Arguments
- `loads_kw::Vector{<:Real}`: Hourly load values from source year
- `source_year::Int`: Year of the source data
- `target_year::Int`: Year to align to
- `method::String`: Alignment method ("weekday_rotation" or "none")
- `preserve_monthly::Bool`: Whether to preserve monthly energy totals (default: true)
- `leap_policy::String`: How to handle leap years (default: "truncate_dec31")

# Returns
- `Tuple{Vector{Float64}, AlignmentMetadata}`: Aligned loads and metadata

# Example
```julia
# Align 2016 site load to 2025
aligned_loads, metadata = align_series_to_year(site_loads_2016, 2016, 2025)

# Check alignment quality
@assert metadata.energy_error < 0.0001  # Less than 0.0001% error
println("Shifted by \$(metadata.shift_days) days")
```
"""
function align_series_to_year(loads_kw::Vector{<:Real}, source_year::Int, target_year::Int;
                             method::String = "weekday_rotation",
                             preserve_monthly::Bool = true,
                             leap_policy::String = "truncate_dec31")::Tuple{Vector{Float64}, AlignmentMetadata}
    
    # Normalize to 8760 hours
    loads_normalized = normalize_to_8760(loads_kw, source_year; leap_policy=leap_policy)
    original_energy = sum(loads_normalized)
    
    # If same year and no method, return as-is
    if source_year == target_year && method == "none"
        metadata = AlignmentMetadata(
            source_year, target_year, method, 0, preserve_monthly, leap_policy,
            "No change - same year", 0.0
        )
        return (loads_normalized, metadata)
    end
    
    # If method is "none", just return the loads (no alignment)
    if method == "none"
        metadata = AlignmentMetadata(
            source_year, target_year, method, 0, preserve_monthly, leap_policy,
            "No alignment performed", 0.0
        )
        return (loads_normalized, metadata)
    end
    
    # Weekday rotation method
    if method != "weekday_rotation"
        throw(ArgumentError("Unknown alignment method: $method. Must be 'weekday_rotation' or 'none'"))
    end
    
    # Calculate shift needed
    shift_days = calculate_weekday_shift(source_year, target_year)
    
    # If no shift needed, return as-is
    if shift_days == 0
        final_energy = sum(loads_normalized)
        energy_error = abs(final_energy - original_energy) / original_energy * 100.0
        metadata = AlignmentMetadata(
            source_year, target_year, method, 0, preserve_monthly, leap_policy,
            "Weekdays already aligned", energy_error
        )
        return (loads_normalized, metadata)
    end
    
    # Perform rotation (shift by days * 24 hours)
    shift_hours = shift_days * 24
    rotated_loads = vcat(loads_normalized[shift_hours+1:end], loads_normalized[1:shift_hours])
    
    # Apply monthly scaling if requested
    if preserve_monthly
        apply_monthly_scaling!(rotated_loads, loads_normalized, source_year, target_year)
        notes = "Rotated daily blocks; monthly energy preserved; leap_policy=$leap_policy"
    else
        notes = "Rotated daily blocks; leap_policy=$leap_policy"
    end
    
    # Calculate energy error
    final_energy = sum(rotated_loads)
    energy_error = abs(final_energy - original_energy) / original_energy * 100.0
    
    metadata = AlignmentMetadata(
        source_year, target_year, method, shift_days, preserve_monthly, leap_policy,
        notes, energy_error
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

# Example
```julia
reference = select_reference_year(2024, user_selected=2025)  # Returns 2025
reference = select_reference_year(2024)  # Returns 2024 (current year)
```
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
                                          preserve_monthly::Bool = true,
                                          leap_policy::String = "truncate_dec31")

Align multiple load components from different source years to a reference year.

This function coordinates the alignment of multiple load components (e.g., site load,
EV load, industrial load) from potentially different source years to a single reference
year. All components are aligned and then summed to create a total load profile.

# Arguments
- `load_components::Dict{String, Dict{String, Any}}`: Dictionary of load components where each component has:
  - "loads_kw": Vector of hourly load values
  - "year": Source year of the data
- `reference_year::Int`: Target year to align all loads to
- `preserve_monthly::Bool`: Whether to preserve monthly energy (default: true)
- `leap_policy::String`: How to handle leap years (default: "truncate_dec31")

# Returns
- `Tuple{Vector{Float64}, Dict{String, Vector{Float64}}, Dict{String, Any}}`:
  - Total combined load (8760 hours)
  - Dictionary of individual aligned component loads
  - Metadata dictionary with alignment information for each component

# Example
```julia
components = Dict(
    "site_load" => Dict("loads_kw" => site_data, "year" => 2016),
    "ev_load" => Dict("loads_kw" => ev_data, "year" => 2024)
)

total_load, component_loads, metadata = align_multiple_loads_to_reference_year(
    components, 2025
)

# Access results
println("Total annual energy: ", sum(total_load), " kWh")
println("Site contribution: ", sum(component_loads["site_load"]), " kWh")
println("EV contribution: ", sum(component_loads["ev_load"]), " kWh")
```
"""
function align_multiple_loads_to_reference_year(load_components::Dict{String, <:Any},
                                               reference_year::Int;
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
        "preserve_monthly" => preserve_monthly
    )
    
    return (total_load, aligned_components, metadata_dict)
end

# Export public functions
export align_series_to_year, align_multiple_loads_to_reference_year, select_reference_year
export AlignmentMetadata, normalize_to_8760
