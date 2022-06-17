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
    ElectricUtility
ElectricUtility data struct with inner constructor:     
        
```julia
function ElectricUtility(;
    emissions_factor_series_lb_CO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_NOx_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_SO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_PM25_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_CO2_decrease_pct::Float64 = 0.01174,
    emissions_factor_NOx_decrease_pct::Float64 = 0.01174,
    emissions_factor_SO2_decrease_pct::Float64 = 0.01174,
    emissions_factor_PM25_decrease_pct::Float64 = 0.01174,
    outage_start_time_step::Int=0  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_time_step::Int=0  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool=true  # if true the site has two meters (in effect)
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_time_steps::Array{Int,1}=Int[],  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}=Int[],  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{R,1} where R<:Real = [1.0],
    outage_time_steps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations),
    scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations),
    net_metering_limit_kw::Real = 0,
    interconnection_limit_kw::Real = 1.0e9,
    latitude::Real,
    longitude::Real,
    time_steps_per_hour::Int = 1
    )
```
!!! note Outage indexing begins at 1 (not 0) and the outage is inclusive of the outage end time step. 
    For instance, to model a 3-hour outage from 12AM to 3AM on Jan 1, outage_start_time_step = 1 and outage_end_time_step = 3.
    To model a 1-hour outage from 6AM to 7AM on Jan 1, outage_start_time_step = 7 and outage_end_time_step = 7.

"""
mutable struct ElectricUtility
    emissions_region::String # AVERT emissions region
    distance_to_emissions_region_meters::Real  
    emissions_factor_series_lb_CO2_per_kwh::Union{Nothing,Array{<:Real,1}}
    emissions_factor_series_lb_NOx_per_kwh::Union{Nothing,Array{<:Real,1}}
    emissions_factor_series_lb_SO2_per_kwh::Union{Nothing,Array{<:Real,1}}
    emissions_factor_series_lb_PM25_per_kwh::Union{Nothing,Array{<:Real,1}}
    emissions_factor_CO2_decrease_pct::Float64
    emissions_factor_NOx_decrease_pct::Float64
    emissions_factor_SO2_decrease_pct::Float64
    emissions_factor_PM25_decrease_pct::Float64
    outage_start_time_step::Int  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_time_step::Int  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool  # if true the site has two meters (in effect)
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_time_steps::Array{Int,1}  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{R,1} where R<:Real 
    outage_time_steps::Union{Missing, UnitRange} 
    scenarios::Union{Missing, UnitRange} 
    net_metering_limit_kw::Real 
    interconnection_limit_kw::Real 


    function ElectricUtility(;
        emissions_factor_series_lb_CO2_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_NOx_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_SO2_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_PM25_per_kwh::Union{Real, Array{<:Real,1}} = Float64[],
        emissions_factor_CO2_decrease_pct::Real = 0.01174,
        emissions_factor_NOx_decrease_pct::Real = 0.01174,
        emissions_factor_SO2_decrease_pct::Real = 0.01174,
        emissions_factor_PM25_decrease_pct::Real = 0.01174,
        outage_start_time_step::Int=0,  # for modeling a single outage, with critical load spliced into the baseline load ...
        outage_end_time_step::Int=0,  # ... utiltity production_factor = 0 during the outage
        allow_simultaneous_export_import::Bool=true,  # if true the site has two meters (in effect)
        # next 5 variables below used for minimax the expected outage cost,
        # with max taken over outage start time, expectation taken over outage duration
        outage_start_time_steps::Array{Int,1}=Int[],  # we minimize the maximum outage cost over outage start times
        outage_durations::Array{Int,1}=Int[],  # one-to-one with outage_probabilities, outage_durations can be a random variable
        outage_probabilities::Array{<:Real,1}=[1.0],
        outage_time_steps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations),
        scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations),
        net_metering_limit_kw::Real = 0,
        interconnection_limit_kw::Real = 1.0e9,
        latitude::Real,
        longitude::Real,
        time_steps_per_hour::Int = 1
        )

        region_lookup = Dict(
            "AK" => "Alaska",
            "CA" => "California",
            "EMW" => "Great Lakes / Atlantic",
            "NE" => "Northeast",
            "NW" => "Northwest",
            "RM" => "Rocky Mountains",
            "SC" => "Lower Midwest",
            "SE" => "Southeast",
            "SW" => "Southwest",
            "TX" => "Texas",
            "WMW" => "Upper Midwest",
            "HI" => "Hawaii (except Oahu)",
            "HI-Oahu" => "Hawaii (Oahu)"
        )
        
        region_abbr, meters_to_region = region_abbreviation(latitude, longitude)
        emissions_region = get(region_lookup, region_abbr, "")
        emissions_series_dict = Dict{String, Array{<:Real,1}}()

        #TODO: can this section be refactored by emissions_type by using Symbol("") technique?
        #eval(Meta.parse("emissions_factor_series_lb_$(pollutant)_per_kwh")) does not work because
        #eval is in global scope and doesn't have access to function arguments
        for (eseries, ekey) in [
            (emissions_factor_series_lb_CO2_per_kwh, "CO2"),
            (emissions_factor_series_lb_NOx_per_kwh, "NOx"),
            (emissions_factor_series_lb_SO2_per_kwh, "SO2"),
            (emissions_factor_series_lb_PM25_per_kwh, "PM25")
        ]
            if typeof(eseries) <: Real
                emissions_series_dict[ekey] = repeat([eseries], 8760*time_steps_per_hour)
            elseif length(eseries) == 1
                emissions_series_dict[ekey] = repeat(eseries, 8760*time_steps_per_hour)
            elseif length(eseries) / time_steps_per_hour ≈ 8760
                emissions_series_dict[ekey] = eseries
            elseif isempty(eseries)
                emissions_series_dict[ekey] = emissions_series(ekey, region_abbr, time_steps_per_hour=time_steps_per_hour)
            else
                throw(@error "Provided ElectricUtility emissions factor series for $(ekey) does not match the time_steps_per_hour.")
            end
        end

        # Error if outage_start/end_time_step is provided and outage_start_time_steps not empty
        if (outage_start_time_step != 0 || outage_end_time_step !=0) && outage_start_time_steps != [] 
            throw(@error "Cannot supply singular outage_start(or end)_time_step and multiple outage_start_time_steps. Please use one or the other.")
        end

        new(
            emissions_region,
            meters_to_region,
            emissions_series_dict["CO2"],
            emissions_series_dict["NOx"],
            emissions_series_dict["SO2"],
            emissions_series_dict["PM25"],
            emissions_factor_CO2_decrease_pct,
            emissions_factor_NOx_decrease_pct,
            emissions_factor_SO2_decrease_pct,
            emissions_factor_PM25_decrease_pct,
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
        @info "Could not find AVERT region containing site latitude/longitude. Checking site proximity to AVERT regions."
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
            # println("Before: $(ArchGDAL.toWKT(point))")
            ArchGDAL.transform!(pt, transform)
            # println("After: $(ArchGDAL.toWKT(point))")
        end
    catch
        @warn "Could not look up AVERT region closest to point ($(latitude), $(longitude)). Location is
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
            return ArchGDAL.getfield(feature,1), meters_to_region
        end
    end
end

function emissions_series(pollutant, region_abbr; time_steps_per_hour=1)
    if isnothing(region_abbr)
        return zeros(8760*time_steps_per_hour)
    end
    # Columns 1 and 2 do not contain AVERT region information, so skip them
    avert_df = readdlm(joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "AVERT_marg_emissions_lb$(pollutant)_per_kwh.csv"), ',')[:, 3:end]

    try
        # Find col index for region, and then row 1 does not contain AVERT data so skip that.
        emissions_profile = round.(avert_df[2:end,findfirst(x -> x == region_abbr, avert_df[1,:])], digits=6)
        if time_steps_per_hour > 1
            emissions_profile = repeat(emissions_profile,inner=time_steps_per_hour)
        end
        return emissions_profile
    catch
        @warn "Emissions error. Cannnot find hourly $(pollutant) emmissions for region $(region_abbr)."
        return nothing
    end
end
