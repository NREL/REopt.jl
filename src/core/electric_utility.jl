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

```julia
function ElectricUtility(;
    emissions_region::String = "",
    emissions_factor_series_lb_CO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_NOx_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_SO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_series_lb_PM25_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
    emissions_factor_CO2_decrease_pct::Float64 = 0.01174,
    emissions_factor_NOX_decrease_pct::Float64 = 0.01174,
    emissions_factor_SO2_decrease_pct::Float64 = 0.01174,
    emissions_factor_PM25_decrease_pct::Float64 = 0.01174,
    outage_start_time_step::Int=0  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_time_step::Int=0  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool=true  # if true the site has two meters (in effect)
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_timesteps::Array{Int,1}=Int[]  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}=Int[]  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{<:Real,1}=[1.0]
    outage_timesteps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations)
    scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations)
    net_metering_limit_kw::Real = 0,
    interconnection_limit_kw::Real = 1.0e9,
    latitude::Real,
    longitude::Real,
    time_steps_per_hour::Int = 1
    )
```

"""
struct ElectricUtility
    emissions_region
    emissions_factor_series_lb_CO2_per_kwh
    emissions_factor_series_lb_NOx_per_kwh
    emissions_factor_series_lb_SO2_per_kwh
    emissions_factor_series_lb_PM25_per_kwh
    emissions_factor_CO2_decrease_pct
    emissions_factor_NOX_decrease_pct
    emissions_factor_SO2_decrease_pct
    emissions_factor_PM25_decrease_pct
    outage_start_time_step
    outage_end_time_step
    allow_simultaneous_export_import
    # next 5 variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_timesteps
    outage_durations
    outage_probabilities
    outage_timesteps
    scenarios
    net_metering_limit_kw
    interconnection_limit_kw

    function ElectricUtility(;
        emissions_factor_series_lb_CO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_NOx_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_SO2_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
        emissions_factor_series_lb_PM25_per_kwh::Union{Float64,Array{<:Real,1}} = Float64[],
        emissions_factor_CO2_decrease_pct::Float64 = 0.01174,
        emissions_factor_NOX_decrease_pct::Float64 = 0.01174,
        emissions_factor_SO2_decrease_pct::Float64 = 0.01174,
        emissions_factor_PM25_decrease_pct::Float64 = 0.01174,
        outage_start_time_step::Int=0,  # for modeling a single outage, with critical load spliced into the baseline load ...
        outage_end_time_step::Int=0,  # ... utiltity production_factor = 0 during the outage
        allow_simultaneous_export_import::Bool=true,  # if true the site has two meters (in effect)
        # next 5 variables below used for minimax the expected outage cost,
        # with max taken over outage start time, expectation taken over outage duration
        outage_start_timesteps::Array{Int,1}=Int[],  # we minimize the maximum outage cost over outage start times
        outage_durations::Array{Int,1}=Int[],  # one-to-one with outage_probabilities, outage_durations can be a random variable
        outage_probabilities::Array{<:Real,1}=[1.0],
        outage_timesteps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations),
        scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations),
        net_metering_limit_kw::Real = 0,
        interconnection_limit_kw::Real = 1.0e9,
        latitude::Real,
        longitude::Real,
        time_steps_per_hour::Int = 1
        )

        region_abbr, meters_to_region = region_abbreviation(latitude, longitude)
        emissions_region = region(region_abbr)
        emissions_series_dict = Dict{String,Array{Float64}}()

        if typeof(emissions_factor_series_lb_CO2_per_kwh) == Float64
            emissions_series_dict["CO2"] = repeat([emissions_factor_series_lb_CO2_per_kwh], 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_CO2_per_kwh) == 1
            emissions_series_dict["CO2"] = repeat(emissions_factor_series_lb_CO2_per_kwh, 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_CO2_per_kwh) / time_steps_per_hour ≈ 8760
            emissions_series_dict["CO2"] = emissions_factor_series_lb_CO2_per_kwh
        elseif isempty(emissions_factor_series_lb_CO2_per_kwh)
            emissions_series_dict["CO2"] = emissions_series("CO2", region_abbr, time_steps_per_hour=time_steps_per_hour)
        else
            @error "Provided emissions_factor_series_lb_CO2_per_kwh does not match the time_steps_per_hour."
        end
        if typeof(emissions_factor_series_lb_NOx_per_kwh) == Float64
            emissions_series_dict["NOx"] = repeat([emissions_factor_series_lb_NOx_per_kwh], 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_NOx_per_kwh) == 1
            emissions_series_dict["NOx"] = repeat(emissions_factor_series_lb_NOx_per_kwh, 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_NOx_per_kwh) / time_steps_per_hour ≈ 8760
            emissions_series_dict["NOx"] = emissions_factor_series_lb_NOx_per_kwh
        elseif isempty(emissions_factor_series_lb_NOx_per_kwh)
            emissions_series_dict["NOx"] = emissions_series("NOx", region_abbr, time_steps_per_hour=time_steps_per_hour)
        else
            @error "Provided emissions_factor_series_lb_NOx_per_kwh does not match the time_steps_per_hour."
        end
        if typeof(emissions_factor_series_lb_SO2_per_kwh) == Float64
            emissions_series_dict["SO2"] = repeat([emissions_factor_series_lb_SO2_per_kwh], 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_SO2_per_kwh) == 1
            emissions_series_dict["SO2"] = repeat(emissions_factor_series_lb_SO2_per_kwh, 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_SO2_per_kwh) / time_steps_per_hour ≈ 8760
            emissions_series_dict["SO2"] = emissions_factor_series_lb_SO2_per_kwh
        elseif isempty(emissions_factor_series_lb_SO2_per_kwh)
            emissions_series_dict["SO2"] = emissions_series("SO2", region_abbr, time_steps_per_hour=time_steps_per_hour)
        else
            @error "Provided emissions_factor_series_lb_SO2_per_kwh does not match the time_steps_per_hour."
        end
        if typeof(emissions_factor_series_lb_PM25_per_kwh) == Float64
            emissions_series_dict["PM25"] = repeat([emissions_factor_series_lb_PM25_per_kwh], 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_PM25_per_kwh) == 1
            emissions_series_dict["PM25"] = repeat(emissions_factor_series_lb_PM25_per_kwh, 8760*time_steps_per_hour)
        elseif length(emissions_factor_series_lb_PM25_per_kwh) / time_steps_per_hour ≈ 8760
            emissions_series_dict["PM25"] = emissions_factor_series_lb_PM25_per_kwh
        elseif isempty(emissions_factor_series_lb_PM25_per_kwh)
            emissions_series_dict["PM25"] = emissions_series("PM25", region_abbr, time_steps_per_hour=time_steps_per_hour)
        else
            @error "Provided emissions_factor_series_lb_PM25_per_kwh does not match the time_steps_per_hour."
        end

        #TODO factor above code by pollutant (attempt below gave UndefVarError on eval() calls)
        # for pollutant in ["CO2", "NOx", "SO2", "PM25"]
        #     field_name = "emissions_factor_series_lb_$(pollutant)_per_kwh"
        #     # If user supplies single emissions rate
        #     if typeof(eval(Meta.parse(field_name))) == Float64
        #         emissions_series_dict[pollutant] = repeat([eval(Meta.parse(field_name))], 8760*time_steps_per_hour)
        #     elseif length(eval(Meta.parse(field_name))) == 1
        #         emissions_series_dict[pollutant] = repeat(eval(Meta.parse(field_name)), 8760*time_steps_per_hour)
        #     elseif length(eval(Meta.parse(field_name))) / time_steps_per_hour ≈ 8760
        #         emissions_series_dict[pollutant] = eval(Meta.parse(field_name))
        #     elseif isempty(eval(Meta.parse(field_name)))
        #         emissions_series_dict[pollutant] = emissions_series(pollutant, region_abbr, time_steps_per_hour=time_steps_per_hour)
                
        #         #TODO deal with emissions warnings and errors appropriately
        #         #above are set to nothing if failed, then (when creating reopt inputs?) check if settings have include __ in objective, and if so @error
        #         # # Emissions warning is a specific type of warning that we check for and display to the users when it occurs
        #         # # If emissions are not required to do a run it tells the user why we could not get an emission series 
        #         # # and sets emissions factors to zero 
        #         # self.emission_warning = str(e.args[0])
        #         # emissions_series = [0.0]*(8760*ts_per_hour) # Set emissions to 0 and return error
        #         # emissions_region = 'None'
        #         # if must_include_CO2 and pollutant=='CO2':
        #         #     self.input_data_errors.append('To include climate emissions in the optimization model, you must either: enter a custom emissions_factor_series_lb_CO2_per_kwh or a site location within the continental U.S.')
        #         # if must_include_health and (pollutant=='NOx' or pollutant=='SO2' or pollutant=='PM25'):
        #         #     self.input_data_errors.append('To include health emissions in the optimization model, you must either: enter a custom emissions_factor_series for health emissions or a site location within the continental U.S.')
        #     else
        #         @error "Provided $(field_name) does not match the time_steps_per_hour."
        #     end
        # end

        new(
            emissions_region,
            emissions_series_dict["CO2"],
            emissions_series_dict["NOx"],
            emissions_series_dict["SO2"],
            emissions_series_dict["PM25"],
            emissions_factor_CO2_decrease_pct,
            emissions_factor_NOX_decrease_pct,
            emissions_factor_SO2_decrease_pct,
            emissions_factor_PM25_decrease_pct,
            outage_start_time_step,
            outage_end_time_step,
            allow_simultaneous_export_import,
            outage_start_timesteps,
            outage_durations,
            outage_probabilities,
            outage_timesteps,
            scenarios,
            net_metering_limit_kw,
            interconnection_limit_kw)
    end
end

function region(region_abbr::String)
    lookup = Dict(
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
    try
        return lookup[region_abbr]
    catch
        return "None"
    end
end

function region_abbreviation(latitude, longitude)
    
    file_path = joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "avert_4326.shp")

    table = Shapefile.Table(file_path)
    geoms = Shapefile.shapes(table)

    # Set defaults
    abbr = nothing
    meters_to_region = nothing

    ## Check if coordinates are in any of the AVERT zones for given shapefile.
    # TODO following for loop is relatively slow, and maybe incorrect because of longitude curving?
    for (row, geo) in enumerate(geoms)
        g = length(geo.points)
        nodes = zeros(g, 2)
        edges = zeros(g, 2)
        for (i,p) in enumerate(geo.points)
            nodes[i,:] = [p.x, p.y]
            edges[i,:] = [i, i+1]
        end
        edges[g, :] = [g, 1]
        edges = convert(Array{Int64,2}, edges)
        # shapefiles have longitude as x, latitude as y  
        if inpoly2([longitude, latitude], nodes, edges)[1]
            abbr = table.AVERT[row]
            meters_to_region = 0
            return abbr, meters_to_region
        end
        GC.gc()
    end

    """
    If region abbreviation from above is nothing then are our lat/lon coords near any avert zone?:
    """
    if abbr === nothing
        
        shpfile = ArchGDAL.read(joinpath(dirname(@__FILE__), "..", "..", "data", "avert","avert_102008.shp"))
        avert_102008 = ArchGDAL.getlayer(shpfile, 0)
        
        point = ArchGDAL.createpoint(latitude, longitude)
        
        try
            # EPSG 4326 is WGS 84 -- WGS84 - World Geodetic System 1984, used in GPS
            fromProj = ArchGDAL.importEPSG(4326)
            # Got below from https://epsg.io/102008
            toProj = ArchGDAL.importPROJ4("+proj=aea +lat_1=20 +lat_2=60 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs")
            ArchGDAL.createcoordtrans(fromProj, toProj) do transform
                # println("Before: $(ArchGDAL.toWKT(point))")
                ArchGDAL.transform!(point, transform)
                # println("After: $(ArchGDAL.toWKT(point))")
            end
        catch
            @warn "Could not look up AVERT emissions region from point (",latitude,",",longitude,"). Location is
            likely invalid or well outside continental US, AK and HI"
            return nothing, nothing
        end

        # For each item, get geometry and append distance between point and geometry to vector.
        distances = []
        for i in 1:ArchGDAL.nfeature(avert_102008)
            ArchGDAL.getfeature(avert_102008,i-1) do f # 0 indexed
                push!(distances, ArchGDAL.distance(ArchGDAL.getgeom(f), point))
            end
        end
        
        ArchGDAL.getfeature(avert_102008,argmin(distances)-1) do feature	# 0 indexed
            region_abbr = ArchGDAL.getfield(feature,1)
            meters_to_region = distances[argmin(distances)]
        end
        
        if meters_to_region > 8046
            @warn "Your site location (", latitude,",",longitude,") is more than 5 miles from the nearest emission region. Cannot calculate emissions."
            return nothing, nothing
        end
        return region_abbr, meters_to_region
    end;

    
    #     gdf_query = gdf[gdf.geometry.intersects(g.Point(self.longitude, self.latitude))]
    #     if not gdf_query.empty:
    #         self.meters_to_region = 0
    #         self._region_abbr = gdf_query.AVERT.values[0]
            
    #     if self._region_abbr is None:
    #         gdf = gpd.read_file(os.path.join(self.library_path,'avert_102008.shp'))
    #         try:
    #             Shapefly transform shapely.ops.transform(func, geom)
    #             lookup = transform(self.project4326_to_102008, g.Point(self.latitude, self.longitude)) # switched lat and long here
    #         except:
    #             raise AttributeError("Could not look up AVERT emissions region from point ({},{}). Location is\
    #                 likely invalid or well outside continental US, AK and HI".format(self.longitude, self.latitude))
    #         distances_meter = gdf.geometry.apply(lambda x : x.distance(lookup)).values
    #         min_idx = list(distances_meter).index(min(distances_meter))
    #         self._region_abbr = gdf.loc[min_idx,'AVERT']
    #         self.meters_to_region = int(round(min(distances_meter)))
    #         if self.meters_to_region > 8046:
    #             raise AttributeError('Your site location ({},{}) is more than 5 miles from the '
    #                 'nearest emission region. Cannot calculate emissions.'.format(self.longitude, self.latitude))
    # return self._region_abbr

    #with GMT.jl ?
    # shape_data = gmtread("pts.shp")
    # shape_data.ds_bbox #global bounding box
    # shape_data. bbox #segment bounding box

    # with proj4.jl
    # From https://epsg.io/102008 proj4 text for 102008: 
    # trans = Proj4.Transformation("EPSG:4326", "+proj=aea +lat_1=20 +lat_2=60 +lat_0=40 +lon_0=-96 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs")
    # trans([55, 12]) => results in SVector{2, Float64}(691875.632, 6098907.825)
    # SVector is from StatisArrays.jl which is a dependency for DiffResults, so it should already be precompiled?
end

function emissions_series(pollutant, region_abbr; time_steps_per_hour=1)
    avert_df = DataFrame(CSV.File(joinpath(@__DIR__, "..", "..", "data", "emissions", "AVERT_Data", "AVERT_hourly_emissions_$(pollutant).csv")))
    if region_abbr in names(avert_df)
        emmissions_profile = round.(avert_df[!,region_abbr],digits=6)
        if time_steps_per_hour > 1
            emmissions_profile = repeat(emmissions_profile,inner=time_steps_per_hour)
        end
        return emmissions_profile
    else
        @warn "Emissions error. Cannnot find hourly emmissions for region $(region_abbr)."
        return zeros(8760*time_steps_per_hour)
    end

        # df = pd.read_csv(os.path.join(self.library_path,'AVERT_hourly_emissions_{}.csv'.format(self.pollutant)), dtype='float64', float_precision='high')
        # if region_abbr in df.columns:
        #     self._emmissions_profile = list(df[self.region_abbr].round(6).values)
        #     if self.time_steps_per_hour > 1:
        #         self._emmissions_profile = list(np.concatenate([[i] * self.time_steps_per_hour for i in self._emmissions_profile]))
        # else:
        #     raise AttributeError("Emissions error. Cannnot find hourly emmissions for region {} ({},{}) \
        #         ".format(self.region, self.latitude,self.longitude)) 
end