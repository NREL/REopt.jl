# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricUtility` is an optional REopt input with the following keys and default values:
```julia
    net_metering_limit_kw::Real = 0,
    interconnection_limit_kw::Real = 1.0e9, # Limit on total electric system capacity size that can be interconnected to the grid 
    outage_start_time_step::Int=0,  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_time_step::Int=0,  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool = true,  # if true the site has two meters (in effect)
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_time_steps::Array{Int,1}=Int[],  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}=Int[],  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{R,1} where R<:Real = [1.0],
    # Emissions and renewable energy inputs:
    emissions_region::String = "", # AVERT emissions region. Default is based on location, or can be overriden by providing region here.
    emissions_factor_series_lb_CO2_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_series_lb_NOx_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_series_lb_SO2_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_series_lb_PM25_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_CO2_decrease_fraction::Real = 0.01174, # Annual percent decrease in the total annual CO2 emissions rate of the grid. A negative value indicates an annual increase.
    emissions_factor_NOx_decrease_fraction::Real = 0.01174,
    emissions_factor_SO2_decrease_fraction::Real = 0.01174,
    emissions_factor_PM25_decrease_fraction::Real = 0.01174
```

!!! note "Outage modeling"
    # Indexing
    Outage indexing begins at 1 (not 0) and the outage is inclusive of the outage end time step. 
    For instance, to model a 3-hour outage from 12AM to 3AM on Jan 1, outage_start_time_step = 1 and outage_end_time_step = 3.
    To model a 1-hour outage from 6AM to 7AM on Jan 1, outage_start_time_step = 7 and outage_end_time_step = 7.

    # Can use either singular or multiple outage modeling inputs, not both
    Cannot supply singular outage_start(or end)_time_step and multiple outage_start_time_steps. Must use one or the other.

    # Using min_resil_time_steps to ensure critical load is met
    With multiple outage modeling, the model will choose to meet the critical loads only as cost-optimal. This trade-off depends on cost of not meeting load (see `Financial | value_of_lost_load_per_kwh`) 
    and the costs of meeting load, such as microgrid upgrade cost (see `Financial | microgrid_upgrade_cost_fraction`), fuel costs, and additional DER capacity. To ensure that REopt recommends a system that can meet 
    critical loads during a defined outage period, specify this duration using `Site | min_resil_time_steps`.

    # Outage costs will be included in NPV and LCC
    Note that when using multiple outage modeling, the expected outage cost will be included in the net present value and lifecycle cost calculations (for both the BAU and optimized case). 
    You can set `Financial | value_of_lost_load_per_kwh` to 0 to ignore these costs. However, doing so will remove incentive for the model to meet critical loads during outages, 
    and you should therefore consider also specifying `Site | min_resil_time_steps`. You can alternatively post-process results to remove `lifecycle_outage_cost` from the NPV and LCCs.

!!! note "Outages, Emissions, and Renewable Energy Calculations"
    If a single deterministic outage is modeled using outage_start_time_step and outage_end_time_step,
    emissions and renewable energy percentage calculations and constraints will factor in this outage.
    If stochastic outages are modeled using outage_start_time_steps, outage_durations, and outage_probabilities,
    emissions and renewable energy percentage calculations and constraints will not consider outages.
    
!!! note "MPC vs. Non-MPC"
    This constructor is intended to be used with latitude/longitude arguments provided for
    the non-MPC case and without latitude/longitude arguments provided for the MPC case.

!!! note "Emissions Region"
    The default `emissions_region` input is determined by the site's latitude and longitude. 
    Alternatively, you may input the desired AVERT `emissions_region`, which must be one of: 
    ["California", "Central", "Florida", "Mid-Atlantic", "Midwest", "Carolinas", "New England",
     "Northwest", "New York", "Rocky Mountains", "Southeast", "Southwest", "Tennessee", "Texas",
     "Alaska", "Hawaii (except Oahu)", "Hawaii (Oahu)"]


"""
struct ElectricUtility
    emissions_region::String # AVERT emissions region
    distance_to_emissions_region_meters::Real
    emissions_factor_series_lb_CO2_per_kwh::Array{<:Real,1}
    emissions_factor_series_lb_NOx_per_kwh::Array{<:Real,1}
    emissions_factor_series_lb_SO2_per_kwh::Array{<:Real,1}
    emissions_factor_series_lb_PM25_per_kwh::Array{<:Real,1}
    emissions_factor_CO2_decrease_fraction::Real
    emissions_factor_NOx_decrease_fraction::Real
    emissions_factor_SO2_decrease_fraction::Real
    emissions_factor_PM25_decrease_fraction::Real
    outage_start_time_step::Int  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_time_step::Int  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool  # if true the site has two meters (in effect)
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_time_steps::Array{Int,1}  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{R,1} where R<:Real 
    outage_time_steps::Union{Nothing, UnitRange} 
    scenarios::Union{Nothing, UnitRange} 
    net_metering_limit_kw::Real 
    interconnection_limit_kw::Real 


    function ElectricUtility(;
        latitude::Union{Nothing,Real} = nothing,
        longitude::Union{Nothing,Real} = nothing,
        off_grid_flag::Bool = false,
        time_steps_per_hour::Int = 1,
        net_metering_limit_kw::Real = 0,
        interconnection_limit_kw::Real = 1.0e9,
        outage_start_time_step::Int=0,  # for modeling a single outage, with critical load spliced into the baseline load ...
        outage_end_time_step::Int=0,  # ... utiltity production_factor = 0 during the outage
        allow_simultaneous_export_import::Bool=true,  # if true the site has two meters (in effect)
        # next 5 variables below used for minimax the expected outage cost,
        # with max taken over outage start time, expectation taken over outage duration
        outage_start_time_steps::Array{Int,1}=Int[],  # we include in the minimization the maximum outage cost over outage start times
        outage_durations::Array{Int,1}=Int[],  # one-to-one with outage_probabilities, outage_durations can be a random variable
        outage_probabilities::Array{<:Real,1} = isempty(outage_durations) ? Float64[] : [1/length(outage_durations) for p_i in 1:length(outage_durations)],
        outage_time_steps::Union{Nothing, UnitRange} = isempty(outage_durations) ? nothing : 1:maximum(outage_durations),
        scenarios::Union{Nothing, UnitRange} = isempty(outage_durations) ? nothing : 1:length(outage_durations),
        # Emissions and renewable energy inputs:
        emissions_region::String = "", # AVERT emissions region, use empty string instead of nothing because that's how missing strings stored in django
        emissions_factor_series_lb_CO2_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_NOx_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_SO2_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_PM25_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_CO2_decrease_fraction::Real = 0.01174,
        emissions_factor_NOx_decrease_fraction::Real = 0.01174,
        emissions_factor_SO2_decrease_fraction::Real = 0.01174,
        emissions_factor_PM25_decrease_fraction::Real = 0.01174,
        # fields from other models needed for validation
        CO2_emissions_reduction_min_fraction::Union{Real, Nothing} = nothing, # passed from Site
        CO2_emissions_reduction_max_fraction::Union{Real, Nothing} = nothing, # passed from Site
        min_resil_time_steps::Int=0, # passed from Site
        include_climate_in_objective::Bool = false, # passed from Settings
        include_health_in_objective::Bool = false # passed from Settings
        )

        is_MPC = isnothing(latitude) || isnothing(longitude)
        if !is_MPC    
            if emissions_region == ""
                region_abbr, meters_to_region = region_abbreviation(latitude, longitude)
                emissions_region = region_abbr_to_name(region_abbr)
            else
                region_abbr = region_name_to_abbr(emissions_region)
                meters_to_region = 0
            end
            emissions_series_dict = Dict{String, Union{Nothing,Array{<:Real,1}}}()

            for (eseries, ekey) in [
                (emissions_factor_series_lb_CO2_per_kwh, "CO2"),
                (emissions_factor_series_lb_NOx_per_kwh, "NOx"),
                (emissions_factor_series_lb_SO2_per_kwh, "SO2"),
                (emissions_factor_series_lb_PM25_per_kwh, "PM25")
            ]
                if typeof(eseries) <: Real  # user provided scaler value
                    emissions_series_dict[ekey] = repeat([eseries], 8760*time_steps_per_hour)
                elseif length(eseries) == 1  # user provided array of one value
                    emissions_series_dict[ekey] = repeat(eseries, 8760*time_steps_per_hour)
                elseif length(eseries) / time_steps_per_hour ≈ 8760  # user provided array with correct length
                    emissions_series_dict[ekey] = eseries
                else
                    if length(eseries) > 1 && !(length(eseries) / time_steps_per_hour ≈ 8760)  # user provided array with incorrect length
                        @warn "Provided ElectricUtility emissions factor series for $(ekey) will be ignored because it does not match the time_steps_per_hour. AVERT emissions data will be used."
                    end
                    emissions_series_dict[ekey] = emissions_series(ekey, region_abbr, time_steps_per_hour=time_steps_per_hour)
                    #Handle missing emissions inputs (due to failed lookup and not provided by user)
                    if isnothing(emissions_series_dict[ekey])
                        @warn "Cannot find hourly $(ekey) emissions for region $(region_abbr). Setting emissions to zero."
                        if ekey == "CO2" && !off_grid_flag && 
                                            (!isnothing(CO2_emissions_reduction_min_fraction) || 
                                            !isnothing(CO2_emissions_reduction_max_fraction) || 
                                            include_climate_in_objective)
                            throw(@error("To include CO2 costs in the objective function or enforce emissions reduction constraints, 
                                you must either enter custom CO2 grid emissions factors or a site location within the continental U.S."))
                        elseif ekey in ["NOx", "SO2", "PM25"] && !off_grid_flag && include_health_in_objective
                            throw(@error("To include health costs in the objective function, you must either enter custom health 
                                grid emissions factors or a site location within the continental U.S."))
                        end
                        emissions_series_dict[ekey] = zeros(8760*time_steps_per_hour)
                    end
                end
            end
        end
        
        if !isempty(outage_durations) && min_resil_time_steps > maximum(outage_durations)
            throw(@error("Site input min_resil_time_steps cannot be greater than the maximum value in ElectricUtility input outage_durations"))
        end
        if (!isempty(outage_start_time_steps) && isempty(outage_durations)) || (isempty(outage_start_time_steps) && !isempty(outage_durations))
            throw(@error("ElectricUtility inputs outage_start_time_steps and outage_durations must both be provided to model multiple outages"))
        end
        if (outage_start_time_step == 0 && outage_end_time_step != 0) || (outage_start_time_step != 0 && outage_end_time_step == 0)
            throw(@error("ElectricUtility inputs outage_start_time_step and outage_end_time_step must both be provided to model an outage"))
        end
        if !isempty(outage_start_time_steps)
            if outage_start_time_step != 0 && outage_end_time_step !=0
                # Warn if outage_start/end_time_step is provided and outage_start_time_steps not empty
                throw(@error("Cannot supply both outage_start(/end)_time_step for deterministic outage modeling and 
                    multiple outage_start_time_steps for stochastic outage modeling. Please use one or the other."))
            else
                @warn "When using stochastic outage modeling (i.e. outage_start_time_steps, outage_durations, outage_probabilities), 
                    emissions and renewable energy percentage calculations and constraints do not consider outages."
            end
        end
        if length(outage_durations) != length(outage_probabilities)
            throw(@error("ElectricUtility inputs outage_durations and outage_probabilities must be the same length"))
        end
        if length(outage_probabilities) >= 1 && (sum(outage_probabilities) < 0.99999 || sum(outage_probabilities) > 1.00001)
            throw(@error("Sum of ElectricUtility inputs outage_probabilities must be equal to 1"))
        end

        new(
            is_MPC ? "" : emissions_region,
            is_MPC || isnothing(meters_to_region) ? typemax(Int64) : meters_to_region,
            is_MPC ? Float64[] : emissions_series_dict["CO2"],
            is_MPC ? Float64[] : emissions_series_dict["NOx"],
            is_MPC ? Float64[] : emissions_series_dict["SO2"],
            is_MPC ? Float64[] : emissions_series_dict["PM25"],
            emissions_factor_CO2_decrease_fraction,
            emissions_factor_NOx_decrease_fraction,
            emissions_factor_SO2_decrease_fraction,
            emissions_factor_PM25_decrease_fraction,
            outage_start_time_step,
            outage_end_time_step,
            allow_simultaneous_export_import,
            outage_start_time_steps,
            outage_durations,
            outage_probabilities,
            outage_time_steps,
            scenarios,
            net_metering_limit_kw,
            interconnection_limit_kw
        )
    end
end



"""
Determine the region abberviation for a given lat/lon pair.
    1. Checks to see if given point is in an AVERT region
    2. If 1 doesnt work, check to see if our point is near any AVERT regions.
        1. Transform point from NAD83 CRS to EPSG 102008 (NA focused conic projection)
        2. Get distance between point and AVERT zones, store in a vector
        3. If distance from a region < 5 miles, return that region along with distance.

Helpful links:
# https://yeesian.com/ArchGDAL.jl/latest/projections/#:~:text=transform%0A%20%20%20%20point%20%3D%20ArchGDAL.-,fromWKT,-(%22POINT%20(1120351.57%20741921.42
# https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry
# https://epsg.io/102008
"""
function region_abbreviation(latitude, longitude)
    
    file_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "avert_4326.shp")

    abbr = nothing
    meters_to_region = nothing

    shpfile = ArchGDAL.read(file_path)
	avert_layer = ArchGDAL.getlayer(shpfile, 0)

	point = ArchGDAL.fromWKT(string("POINT (",longitude," ",latitude,")"))
    
	for i in 1:ArchGDAL.nfeature(avert_layer)
		ArchGDAL.getfeature(avert_layer,i-1) do feature # 0 indexed
			if ArchGDAL.contains(ArchGDAL.getgeom(feature), point)
				abbr = ArchGDAL.getfield(feature,"AVERT")
                meters_to_region = 0.0;
			end
		end
	end
    if isnothing(abbr)
        @warn "Could not find AVERT region containing site latitude/longitude. Checking site proximity to AVERT regions."
    else
        return abbr, meters_to_region
    end

    shpfile = ArchGDAL.read(joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "avert_102008.shp"))
    avert_102008 = ArchGDAL.getlayer(shpfile, 0)

    pt = ArchGDAL.createpoint(latitude, longitude)

    try
        fromProj = ArchGDAL.importEPSG(4326)
        toProj = ArchGDAL.importPROJ4("+proj=aea +lat_1=20 +lat_2=60 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs")
        ArchGDAL.createcoordtrans(fromProj, toProj) do transform
            ArchGDAL.transform!(pt, transform)
        end
    catch
        @warn "Could not look up AVERT emissions region closest to point ($(latitude), $(longitude)). Location is
        likely invalid or well outside continental US, AK and HI"
        return abbr, meters_to_region #nothing, nothing
    end

    distances = []
    for i in 1:ArchGDAL.nfeature(avert_102008)
        ArchGDAL.getfeature(avert_102008,i-1) do f # 0 indexed
            push!(distances, ArchGDAL.distance(ArchGDAL.getgeom(f), pt))
        end
    end
    
    ArchGDAL.getfeature(avert_102008,argmin(distances)-1) do feature	# 0 indexed
        meters_to_region = distances[argmin(distances)]

        if meters_to_region > 8046
            @warn "Your site location ($(latitude), $(longitude)) is more than 5 miles from the nearest AVERT region. Cannot calculate emissions."
            return abbr, meters_to_region #nothing, #
        else
            return ArchGDAL.getfield(feature,"AVERT"), meters_to_region
        end
    end
end

function emissions_series(pollutant, region_abbr; time_steps_per_hour=1)
    if isnothing(region_abbr)
        return nothing
    end
    # Columns 1 and 2 do not contain AVERT region information, so skip them
    avert_df = readdlm(joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "AVERT_2021_$(pollutant)_lb_per_kwh.csv"), ',')[:, 3:end]

    try
        # Find col index for region, and then row 1 does not contain AVERT data so skip that.
        emissions_profile = round.(avert_df[2:end,findfirst(x -> x == region_abbr, avert_df[1,:])], digits=6)
        if time_steps_per_hour > 1
            emissions_profile = repeat(emissions_profile,inner=time_steps_per_hour)
        end
        return emissions_profile
    catch
        return nothing
    end
end

function region_abbr_to_name(region_abbr)
    lookup = Dict(
        "CA" => "California",
        "CENT" => "Central",
        "FL" => "Florida",
        "MIDA" => "Mid-Atlantic",
        "MIDW" => "Midwest",
        "NCSC" => "Carolinas",
        "NE" => "New England",
        "NW" => "Northwest",
        "NY" => "New York",
        "RM" => "Rocky Mountains",
        "SE" => "Southeast",
        "SW" => "Southwest",
        "TN" => "Tennessee",
        "TE" => "Texas",
        "AKGD" => "Alaska",
        "HIMS" => "Hawaii (except Oahu)",
        "HIOA" => "Hawaii (Oahu)"
    )
    return get(lookup, region_abbr, "")
end

function region_name_to_abbr(region_name)
    lookup = Dict(
        "California" => "CA",
        "Central" => "CENT",
        "Florida" => "FL",
        "Mid-Atlantic" => "MIDA",
        "Midwest" => "MIDW",
        "Carolinas" => "NCSC",
        "New England" => "NE",
        "Northwest" => "NW",
        "New York" => "NY",
        "Rocky Mountains" => "RM",
        "Southeast" => "SE",
        "Southwest" => "SW",
        "Tennessee" => "TN",
        "Texas" => "TE",
        "Alaska" => "AKGD",
        "Hawaii (except Oahu)" => "HIMS",
        "Hawaii (Oahu)" => "HIOA"
    )
    return get(lookup, region_name, "")
end

"""
    emissions_profiles(; latitude::Real, longitude::Real, time_steps_per_hour::Int=1)

This function gets CO2, NOx, SO2, and PM2.5 grid emission rate profiles (1-year time series) from the AVERT dataset.
    
This function is used for the /emissions_profile endpoint in the REopt API, in particular 
    for the webtool to display grid emissions defaults before running REopt, 
    but is also generally an external way to access AVERT data without running REopt.
"""
function emissions_profiles(; latitude::Real, longitude::Real, time_steps_per_hour::Int=1)
    region_abbr, meters_to_region = region_abbreviation(latitude, longitude)
    emissions_region = region_abbr_to_name(region_abbr)
    if isnothing(region_abbr)
        return Dict{String, Any}(
                "error"=>
                "Could not look up AVERT emissions region within 5 miles from point ($(latitude), $(longitude)).
                Location is likely invalid or well outside continental US, AK and HI."
            )
    end
    response_dict = Dict{String, Any}(
        "region_abbr" => region_abbr,
        "region" => emissions_region,
        "units" => "Pounds emissions per kWh",
        "description" => "Regional hourly grid emissions factors for applicable EPA AVERT region.",
        "meters_to_region" => meters_to_region
    )
    for ekey in ["CO2", "NOx", "SO2", "PM25"]
        response_dict["emissions_factor_series_lb_"*ekey*"_per_kwh"] = emissions_series(ekey, region_abbr, time_steps_per_hour=time_steps_per_hour)
    end
    return response_dict
end