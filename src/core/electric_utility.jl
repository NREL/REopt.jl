# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
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

    ### Climate Emissions from Grid Electricity ### 
    # Climate Option 1 (Default): Use levelized emissions data from NREL's Cambium database by specifying the following fields:
    "cambium_scenario": "Mid-case" # Cambium Scenario for evolution of electricity sector (see Cambium documentation for descriptions). Default: Mid-case.
        ## Options: "Mid-case", "Low Renewable Energy and Battery Costs", "High Renewable Energy and Battery Costs", "Electricifcation", "Low Natural Gas Price", "High Natural Gas Price", "Mid-case with 95% Decarbonization by 2050", "Mid-case with 100% Decarbonization by 2035", "Mid-case (with tax credit phaseout)", "Low Renewable Energy and Battery Costs (with tax credit phaseout)"      
    "cambium_location_type": "States" # Geographic boundary at which emissions are calculated. Default: States. Options: Nations, GEA Regions, States, Balancing Areas # TODO: some may not work 
    "cambium_location":  # This will automatically populate based on the site's lat-long. Options (should align with location_type): Contiguous United States (TODO: check this), Colorado, p33
    "cambium_metric_col": "lrmer_co2e" # Long-run marginal emissions rate for CO2-equivalant, combined combustion and pre-combustion emissions rates. Options: See metric definitions and names in the Cambium documentation
    "cambium_start_year": 2024 # First year of operation of system. Default: 2024 # Options: any year now through 2050.
    "cambium_lifetime": analysis_years # Expected lifetime or analysis period of the intervention being studied. 
    
    # Climate Option 2: Use CO2 emissions data from the EPA's AVERT 
    use_AVERT_for_CO2::Bool = false # Default is to use Cambium data for CO2 grid emissions. Set to true to instead use data from the EPA's AVERT database. 

    # Climate Option 3: Provide your own custom emissions factors for CO2 and specify annual percent decrease  
    emissions_factor_series_lb_CO2_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # Custom CO2 emissions profile. Can be scalar or timeseries (aligned with time_steps_per_hour)
    
    # Used in Climate Options 2 or 3: Annual percent decrease in CO2 emissions factors
    emissions_factor_CO2_decrease_fraction::Real = 0.01174, # Annual percent decrease in the total annual CO2 emissions rate of the grid. A negative value indicates an annual increase.
    
    ### Health Emissions from Grid Electricity ### 
    # Health Option 1 (Default): Use health emissions data from AVERT based on the AVERT emissions region and specify annual percent decrease
    avert_emissions_region::String = "", # AVERT emissions region. Default is based on location, or can be overriden by providing region here.
    
    # Health Option 2: Provide your own custom emissions factors for health emissions and specify annual percent decrease:
    emissions_factor_series_lb_NOx_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # Custom NOx emissions profile. Can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_series_lb_SO2_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # Custom SO2 emissions profile. Can be scalar or timeseries (aligned with time_steps_per_hour)
    emissions_factor_series_lb_PM25_per_kwh::Union{Real,Array{<:Real,1}} = Float64[], # Custom PM2.5 emissions profile. Can be scalar or timeseries (aligned with time_steps_per_hour)

    # Used in Health Options 1 or 2: Annual percent decrease in health emissions factors: 
    emissions_factor_NOx_decrease_fraction::Real = 0.01174,
    emissions_factor_SO2_decrease_fraction::Real = 0.01174,
    emissions_factor_PM25_decrease_fraction::Real = 0.01174
```

!!! note "Outage modeling"
    Outage indexing begins at 1 (not 0) and the outage is inclusive of the outage end time step. 
    For instance, to model a 3-hour outage from 12AM to 3AM on Jan 1, outage_start_time_step = 1 and outage_end_time_step = 3.
    To model a 1-hour outage from 6AM to 7AM on Jan 1, outage_start_time_step = 7 and outage_end_time_step = 7.

    Cannot supply singular outage_start(or end)_time_step and multiple outage_start_time_steps. Must use one or the other.

!!! note "Outages, Emissions, and Renewable Energy Calculations"
    If a single deterministic outage is modeled using outage_start_time_step and outage_end_time_step,
    emissions and renewable energy percentage calculations and constraints will factor in this outage.
    If stochastic outages are modeled using outage_start_time_steps, outage_durations, and outage_probabilities,
    emissions and renewable energy percentage calculations and constraints will not consider outages.
    
!!! note "MPC vs. Non-MPC"
    This constructor is intended to be used with latitude/longitude arguments provided for
    the non-MPC case and without latitude/longitude arguments provided for the MPC case.

!!! note "Climate and Health Emissions Modeling" 
    Climate and health-related emissions from grid electricity come from two different data sources and have different REopt inputs as described below. 

    **Climate Emissions**
    - For sites in the contiguous United States: 
        - Default climate-related emissions factors (CO2e) come from NREL's Cambium database (Current version: 2022)
            - By default, REopt uses *levelized long-run marginal emission rates for CO2-equivalent emissions* for the state in which the site is located. ## TODO check is BA's work and if not, use state's or GEAs. 
                The emissions rates are levelized over the analysis period (e.g., from 2023 through 2047 for a 25-year analysis)
            - The inputs to the Cambium API request can be modified by the user based on emissions accounting needs (e.g., can change "lifetime" to 1 to analyze a single year's emissions)
                # TODO: put these in Cambium API request:  
                hide: "time_type": "hourly" 
                hide: "grid_level": "enduse" # Options: enduse or busbar
                hide?: "discount_rate": 0 # Zero = simple average
                hide: "smoothing_method": "none" # Options: rolling or none
                hide: "ems_mass_units": "lb" # lb or kg 
                hide: "gwp": "100yrAR6" # Global warming potential values. Default: "100yrAR6". Options: "100yrAR5", "20yrAR5", "100yrAR6", "20yrAR6" or a custom tuple [1,10.0,100] with GWP values for [CO2, CH4, N2O] # TODO check use of custom tuples 

            - Note for analysis periods extending beyond 2050: Values beyond 2050 are estimated with the 2050 values. Analysts are advised to use caution when selecting values that place significant weight on 2050 (e.g., greater than 50%)
        - Users can alternatively choose to use emissions factors from the EPA's AVERT by setting `use_AVERT_for_CO2` to `true`
    - For Alaska and HI: Climate-related emissions rates for AK and HI come from... 
    - For sites outside of the United States: We currently do not have default grid emissions rates for sites outside of the U.S. For these sites, users must supply custom emissions factor series (e.g., emissions_factor_series_lb_CO2_per_kwh) and projected emissions decreases (e.g., emissions_factor_CO2_decrease_fraction). 

    **Health Emissions**
    - For sites in the contiguous United States: health-related emissions factors (PM2.5, SO2, and NOx) come from the EPA's AVERT database. 
    - The default `avert_emissions_region` input is determined by the site's latitude and longitude. 
    Alternatively, you may input the desired AVERT `avert_emissions_region`, which must be one of: 
    ["California", "Central", "Florida", "Mid-Atlantic", "Midwest", "Carolinas", "New England",
     "Northwest", "New York", "Rocky Mountains", "Southeast", "Southwest", "Tennessee", "Texas",
     "Alaska", "Hawaii (except Oahu)", "Hawaii (Oahu)"]

"""
struct ElectricUtility
    avert_emissions_region::String # AVERT emissions region
    distance_to_avert_emissions_region_meters::Real
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
        avert_emissions_region::String = "", # AVERT emissions region, use empty string instead of nothing because that's how missing strings stored in django
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
        include_climate_in_objective::Bool = false, # passed from Settings
        include_health_in_objective::Bool = false # passed from Settings
        )

        is_MPC = isnothing(latitude) || isnothing(longitude)
        if !is_MPC    
            # Get AVERT emissions region
            if avert_emissions_region == ""
                region_abbr, meters_to_region = avert_region_abbreviation(latitude, longitude)
                avert_emissions_region = region_abbr_to_name(region_abbr)
            else
                region_abbr = region_name_to_abbr(avert_emissions_region)
                meters_to_region = 0
            end
            emissions_series_dict = Dict{String, Union{Nothing,Array{<:Real,1}}}()

            for (eseries, ekey) in [
                (emissions_factor_series_lb_CO2_per_kwh, "CO2"),
                (emissions_factor_series_lb_NOx_per_kwh, "NOx"),
                (emissions_factor_series_lb_SO2_per_kwh, "SO2"),
                (emissions_factor_series_lb_PM25_per_kwh, "PM25")
            ]
                if typeof(eseries) <: Real  # user provided scalar value
                    emissions_series_dict[ekey] = repeat([eseries], 8760*time_steps_per_hour)
                elseif length(eseries) == 1  # user provided array of one value
                    emissions_series_dict[ekey] = repeat(eseries, 8760*time_steps_per_hour)
                elseif length(eseries) / time_steps_per_hour ≈ 8760  # user provided array with correct length
                    emissions_series_dict[ekey] = eseries
                elseif length(eseries) > 1 && !(length(eseries) / time_steps_per_hour ≈ 8760)  # user provided array with incorrect length
                    throw(@error("The provided ElectricUtility emissions factor series for $(ekey) does not match the time_steps_per_hour."))
                else # if not user-provided, get emissions factors from AVERT and/or Cambium
                    emissions_series_dict[ekey] = emissions_series(ekey, region_abbr, use_AVERT_for_CO2, time_steps_per_hour=time_steps_per_hour)
                    # Handle missing emissions inputs (due to failed lookup and not provided by user)
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
        
        if (!isempty(outage_start_time_steps) && isempty(outage_durations)) || (isempty(outage_start_time_steps) && !isempty(outage_durations))
            throw(@error("ElectricUtility inputs outage_start_time_steps and outage_durations must both be provided to model multiple outages"))
        end
        if (outage_start_time_step == 0 && outage_end_time_step != 0) || (outage_start_time_step != 0 && outage_end_time_step == 0)
            throw(@error("ElectricUtility inputs outage_start_time_step and outage_end_time_step must both be provided to model a single outage"))
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
            is_MPC ? "" : avert_emissions_region,
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
Determine the AVERT region abberviation for a given lat/lon pair.
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
function avert_region_abbreviation(latitude, longitude)
    
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
        likely invalid or well outside continental US, AK and HI." # TODO: what happens if cannot look this up? 
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

function emissions_series(pollutant, region_abbr, use_AVERT_for_CO2; time_steps_per_hour=1)
    
    # AVERT Lookup
    if pollutant in ["NOx", "SO2", "PM25"] || use_AVERT_for_CO2
        if isnothing(region_abbr)
            return nothing
        end
        # Columns 1 and 2 do not contain AVERT region information, so skip them
        # TODO: Update to latest AVERT data? 
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
    else # For CO2 from Cambium 

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
function emissions_profiles(; latitude::Real, longitude::Real, time_steps_per_hour::Int=1, use_AVERT_for_CO2::Bool=false)
    region_abbr, meters_to_region = avert_region_abbreviation(latitude, longitude)
    avert_emissions_region = region_abbr_to_name(region_abbr)
    if isnothing(region_abbr)
        return Dict{String, Any}(
                "error"=>
                "Could not look up AVERT emissions region within 5 miles from point ($(latitude), $(longitude)).
                Location is likely invalid or well outside continental US, AK and HI."
            )
    end

    ## TODO: distinguish between Cambium CO2 and AVERT data here. 
    response_dict = Dict{String, Any}(
        "region_abbr" => region_abbr,
        "region" => avert_emissions_region,
        "units" => "Pounds emissions per kWh",
        "description" => "Regional hourly grid emissions factors for applicable EPA AVERT region.",
        "meters_to_region" => meters_to_region
    )
    for ekey in ["CO2", "NOx", "SO2", "PM25"]
        response_dict["emissions_factor_series_lb_"*ekey*"_per_kwh"] = emissions_series(ekey, region_abbr, use_AVERT_for_CO2, time_steps_per_hour=time_steps_per_hour)
    end
    return response_dict
end