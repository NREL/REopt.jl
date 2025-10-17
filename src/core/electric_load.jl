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
    annual_kwh::Union{Real, Nothing} = nothing, # scales the load profile to this annual energy. Can apply to either loads_kw (if normalize_and_scale_load_profile_input=true) or doe_reference loads
    monthly_totals_kwh::Array{<:Real,1} = Real[], # scales the load profile to these monthly energy totals. Must provide 12 values. Can apply to either loads_kw (if normalize_and_scale_load_profile_input=true) or doe_reference loads
    monthly_peaks_kw::Array{<:Real,1} = Real[], # scales the load profile to these monthly peak loads. Can apply to either loads_kw (if normalize_and_scale_load_profile_input=true) or doe_reference loads
    critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
    loads_kw_is_net::Bool = true, # set to true if loads_kw is already net of on-site electricity generation.
    critical_loads_kw_is_net::Bool = false, # set to true if critical_loads_kw is already net of on-site electricity generation.
    critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # fractional input is applied to the typical load profile to determine critical loads.
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%. Applied to each time_step as a % of electric load.
    min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0 # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
```

!!! note "Required inputs"
    Must provide either `loads_kw` or `path_to_csv` or [`doe_reference_name` and `city`] or `doe_reference_name` or [`blended_doe_reference_names` and `blended_doe_reference_percents`]. 

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

!!! note "Net Load and Load Scaling Considerations" 
    If `loads_kw` is already net of on-site generation and you are modeling an existing generation source in REopt (e.g., PV), set `loads_kw_is_net=true` (default). 
    If `loads_kw` is net and you are additionally using `normalize_and_scale_load_profile_input` along with `annual_kwh` or `monthly_totals_kwh`, the scaling will be applied 
    to the net loads and the annual or monthly values you supply should also be net. 
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
        monthly_peaks_kw::Array{<:Real,1} = Real[],
        critical_loads_kw::Union{Nothing, Array{Real,1}} = nothing,
        loads_kw_is_net::Bool = true,
        critical_loads_kw_is_net::Bool = false,
        critical_load_fraction::Real = off_grid_flag ? 1.0 : 0.5, # if off grid, must be 1.0, else 0.5
        latitude::Real,
        longitude::Real,
        time_steps_per_hour::Int = 1,
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.1 : 0.0, # if off grid, 10%, else must be 0%
        min_load_met_annual_fraction::Real = off_grid_flag ? 0.99999 : 1.0 # if off grid, 99.999%, else must be 100%. Applied to each time_step as a % of electric load.
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
        else # not off-grid
            if !(operating_reserve_required_fraction == 0.0)
                @warn "ElectricLoad operating_reserve_required_fraction must be 0 for on-grid scenarios. Operating reserve requirements apply to off-grid scenarios only."
                operating_reserve_required_fraction = 0.0
            elseif !(min_load_met_annual_fraction == 1.0)
                @warn "ElectricLoad min_load_met_annual_fraction must be 1.0 for on-grid scenarios. This input applies to off-grid scenarios only."
                min_load_met_annual_fraction = 1.0
            end
        end

        if isnothing(year)
            throw(@error("Must provide ElectricLoad.year when using loads_kw input."))
        end

        if !isempty(path_to_csv)
            try
                loads_kw = vec(readdlm(path_to_csv, ',', Float64, '\n'))
            catch e
                throw(@error("Unable to read in electric load profile from $path_to_csv. Please provide a valid path to a csv with no header."))
            end
        end

        loads_kw = check_and_adjust_load_length(loads_kw, time_steps_per_hour, "ElectricLoad")

        if !isnothing(annual_kwh) && !isempty(monthly_totals_kwh)
            throw(@error("Cannot provide both annual_kwh and monthly_totals_kwh to scale the electric load profile."))
        end
        if length(loads_kw) > 0 && ( !isnothing(annual_kwh) || !isempty(monthly_totals_kwh) || !isempty(monthly_peaks_kw) ) && !normalize_and_scale_load_profile_input
            throw(@error("If providing loads_kw and annual_kwh or monthly_totals_kwh or monthly_peaks_kw, must set normalize_and_scale_load_profile_input=true."))
        end
        if length(loads_kw) > 0 && !normalize_and_scale_load_profile_input
            nothing
        elseif length(loads_kw) > 0 && normalize_and_scale_load_profile_input
            if !isempty(doe_reference_name)
                @warn "loads_kw provided with normalize_and_scale_load_profile_input = true, so ignoring location and doe_reference_name inputs, and only using the year and annual or monthly energy inputs with loads_kw"
            end
            if isnothing(annual_kwh) && isempty(monthly_totals_kwh) && isempty(monthly_peaks_kw)
                throw(@error("Provided loads_kw with normalize_and_scale_load_profile_input=true, but no annual_kwh, monthly_totals_kwh, or monthly_peaks_kw was provided"))
            end
            if !isnothing(annual_kwh) || !isempty(monthly_totals_kwh)
                # Using dummy values for all unneeded location and building type arguments for normalizing and scaling load profile input
                normalized_profile = loads_kw ./ sum(loads_kw)
                loads_kw = BuiltInElectricLoad("Chicago", "LargeOffice", 41.8333, -88.0616, year, annual_kwh, monthly_totals_kwh, normalized_profile; time_steps_per_hour = time_steps_per_hour)
            end
    
        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, year, annual_kwh, monthly_totals_kwh)

        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInElectricLoad, latitude, longitude, year, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_kwh, monthly_totals_kwh)
        else
            throw(@error("Cannot construct ElectricLoad. You must provide either [loads_kw], [doe_reference_name, city], 
                  [doe_reference_name, latitude, longitude], 
                  or [blended_doe_reference_names, blended_doe_reference_percents] with city or latitude and longitude."))
        end

        # Adjust load length for CRBs, which are always 8760, if needed (after energy scaling and blending)
        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating electric load in each hour to match the time_steps_per_hour."
        end

        # Scale to monthly peak loads 
        if !isempty(monthly_peaks_kw)
            if occursin("FlatLoad", doe_reference_name) # TODO: check that we shouldn't scale these
                @warn "Not scaling electric load to monthly_peaks_kw because doe_reference_name is a FlatLoad."
            else
                loads_kw = scale_load_to_monthly_peaks(loads_kw, monthly_peaks_kw, time_steps_per_hour, year)
            end
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
            min_load_met_annual_fraction
        )
    end
end


function BuiltInElectricLoad(
    city::String,
    buildingtype::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    annual_kwh::Union{Real, Nothing}=nothing,
    monthly_totals_kwh::Vector{<:Real}=Real[],
    normalized_profile::Union{Vector{Float64}, Vector{<:Real}}=Real[]; # for custom loads, not CRBs
    time_steps_per_hour::Int = 1 # only used with normalized_profile
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

    built_in_load("electric", city, buildingtype, year, annual_kwh, monthly_totals_kwh, nothing, normalized_profile; time_steps_per_hour=time_steps_per_hour)
end

"""
    scale_load_to_monthly_peaks(
        loads_kw::Vector{Float64}, 
        monthly_peaks_kw::Vector{Float64}, 
        time_steps_per_hour::Int, 
        year::Int   
    )
"""
function scale_load_to_monthly_peaks(
    initial_loads_kw::Vector{Float64}, 
    target_monthly_peaks_kw::Vector{Float64}, 
    time_steps_per_hour::Int, 
    year::Int
    )

    # Error checking
    expected_length = 8760 * time_steps_per_hour
    if length(initial_loads_kw) != expected_length
        error("Load profile must have $expected_length intervals for $time_steps_per_hour time_steps_per_hour")
    end
    if length(target_monthly_peaks_kw) != 12
        error("monthly_peaks_kw must have exactly 12 values")
    end
    if any(x -> x <= 0, target_monthly_peaks_kw)
        error("All monthly_peaks_kw values must be positive")
    end

    monthly_timesteps = get_monthly_time_steps(year; time_steps_per_hour=time_steps_per_hour)
    scaled_load = zeros(Float64, length(initial_loads_kw))
    for month in 1:12
        start_idx = monthly_timesteps[month][1]
        end_idx = monthly_timesteps[month][end]
        month_load_series = initial_loads_kw[start_idx:end_idx]
        initial_peak = maximum(month_load_series)
        target_peak = target_monthly_peaks_kw[month]
        total_consumption_kwh = sum(month_load_series) / time_steps_per_hour
        if initial_peak > target_peak
            scaled_month = apply_linear_flattening(month_load_series, total_consumption_kwh, target_peak)
        else
            scaled_month = apply_exponential_stretching(month_load_series, total_consumption_kwh, initial_peak, target_peak)
        end
        scaled_load[start_idx:end_idx] = scaled_month
    end
    return scaled_load

end

"""
Apply linear flattening when initial peak > actual peak (Condition 1).

Formula: Scaled_Load = initial_Load × x + Flat_Load × (1 - x)
where Flat_Load = Total_Consumption / n

Args:
    initial_load: Array of initial load values for the period
    total_consumption: Total energy consumption for the period (kWh)
    target_peak: Target peak demand (kW)

Returns:
    Profile for given month, scaled to peak
"""
function apply_linear_flattening(initial_load_series_kw::Vector{Float64}, total_consumption_kwh::Float64, target_peak_kw::Float64)

    flat_load_kw = total_consumption_kwh / 8760
    function objective(x)
        scaled = initial_load_series_kw .* x .+ flat_load_kw .* (1 - x)
        return abs(maximum(scaled) - target_peak_kw)
    end
    x_optimal = (findmin([objective(x) for x in 0:0.001:1])[2] - 1 ) * 0.001 # convert from index to x value
    scaled_load_series_kw = initial_load_series_kw .* x_optimal .+ flat_load_kw .* (1 - x_optimal)
    return scaled_load_series_kw
end

"""
Apply exponential stretching when initial peak < actual peak (Condition 2).

Steps:
1. Normalize: Transformed_Load = Initial_Load × (Actual_Peak / Initial_Peak)
2. Apply decay: Scaled_Load = Transformed_Load × e^(-x(1 - Transformed_Load/Actual_Peak))
3. Goal seek x to match total consumption

Args:
    initial_load: Array of initial load values for the period
    total_consumption: Total energy consumption for the period (kWh)
    initial_peak: Peak of initial load (kW)
    target_peak: Target peak demand (kW)

Returns:
    Profile for given month, scaled to peak
"""
function apply_exponential_stretching(initial_load_series_kw::Vector{Float64}, total_consumption_kwh::Float64, initial_peak_kw::Float64, target_peak_kw::Float64)
    transformed_load_series_kw = initial_load_series_kw .* (target_peak_kw / initial_peak_kw)
    function objective(x)
        decay_factor = exp.(-x .* (1 .- transformed_load_series_kw ./ target_peak_kw))
        scaled_load_series_kw = transformed_load_series_kw .* decay_factor
        return abs(sum(scaled_load_series_kw)/time_steps_per_hour - total_consumption_kwh)
    end
    x_optimal = (findmin([objective(x) for x in 0:0.01:10])[2] - 1 ) * 0.01 # convert from index to x value
    decay_factor = exp.(-x_optimal .* (1 .- transformed_load_series_kw ./ target_peak_kw))
    scaled_load_series_kw = transformed_load_series_kw .* decay_factor
    return scaled_load_series_kw
end