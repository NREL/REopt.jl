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

function prodfactor(pv::PV, latitude::Real, longitude::Real; timeframe="hourly")

    if !(ismissing(pv.prod_factor_series))
        return pv.prod_factor_series
    end

    url = string("https://developer.nrel.gov/api/pvwatts/v6.json", "?api_key=", nrel_developer_key,
        "&lat=", latitude , "&lon=", longitude, "&tilt=", pv.tilt,
        "&system_capacity=1", "&azimuth=", pv.azimuth, "&module_type=", pv.module_type,
        "&array_type=", pv.array_type, "&losses=", round(pv.losses*100, digits=3), "&dc_ac_ratio=", pv.dc_ac_ratio,
        "&gcr=", pv.gcr, "&inv_eff=", pv.inv_eff*100, "&timeframe=", timeframe, "&dataset=nsrdb",
        "&radius=", pv.radius
    )

    try
        @info "Querying PVWatts for prodfactor with " pv.name
        r = HTTP.get(url)
        response = JSON.parse(String(r.body))
        if r.status != 200
            error("Bad response from PVWatts: $(response["errors"])")
        end
        @info "PVWatts success."
        watts = collect(get(response["outputs"], "ac", []) / 1000)  # scale to 1 kW system (* 1 kW / 1000 W)
        if length(watts) != 8760
            @error "PVWatts did not return a valid production factor. Got $watts"
        end
        return watts
    catch e
        @error "Error occurred when calling PVWatts: $e"
    end
end


function prodfactor(g::AbstractGenerator; ts_per_hour::Int=1)
    return ones(8760 * ts_per_hour)
end


"""
    prodfactor(wind::Wind, latitude::Real, longitude::Real)

If the user does not provide their own prod_factor_series for the Wind turbine, then this method creates
a production factor time-series using resource data and the System Advisor Model Wind module.
If the user does not provide the resource data, the latitude and longitude are used to get the resource data from the
Wind Toolkit.
"""
function prodfactor(wind::Wind, latitude::Real, longitude::Real, time_steps_per_hour::Int)

    if !(ismissing(wind.prod_factor_series))
        return wind.prod_factor_series
    end

    resources = []
    heights_for_sam = [wind.hub_height]

    if all(length(a) > 0 for a in [wind.temperature_celsius, wind.pressure_atmospheres, wind.wind_direction_degrees,
                                   wind.wind_meters_per_sec])
        push!(resources, [wind.temperature_celsius, wind.pressure_atmospheres, wind.wind_direction_degrees,
                          wind.wind_meters_per_sec])
    else  # download resource data from WindToolKit

        # Allowed hub heights in meters for the Wind Toolkit
        windtoolkit_hub_heights = [10, 40, 60, 80, 100, 120, 140, 160, 200]
        """
        SAM can interpolate the wind power if the wind.hub_height is not one of the windtoolkit_hub_heights.
            If we do need to interpolate then we need to provide SAM with the resources for two hub heights.
        """
        if !(wind.hub_height in windtoolkit_hub_heights)
            if wind.hub_height < minimum(windtoolkit_hub_heights)
                heights_for_sam = [windtoolkit_hub_heights[1]]
            elseif wind.hub_height > maximum(windtoolkit_hub_heights)
                heights_for_sam = [windtoolkit_hub_heights[end]]
            else
                upper_index = findfirst(x -> x > wind.hub_height, windtoolkit_hub_heights)
                heights_for_sam = [windtoolkit_hub_heights[upper_index-1], windtoolkit_hub_heights[upper_index]]
            end
        end
        # TODO validate against API with different hub heights (not in windtoolkit_hub_heights)

        for height in heights_for_sam
            url = string("https://developer.nrel.gov/api/wind-toolkit/v2/wind/wtk-srw-download", 
                "?api_key=", nrel_developer_key,
                "&lat=", latitude , "&lon=", longitude, 
                "&hubheight=", Int(height), "&year=", 2012
            )
            resource = []
            try
                @info "Querying Wind Toolkit for resource data ..."
                r = HTTP.get(url; retries=5)
                if r.status != 200
                    error("Bad response from Wind Toolkit: $(response["errors"])")
                end
                @info "Wind Toolkit success."

                resource = readdlm(IOBuffer(String(r.body)), ',', Float64, '\n'; skipstart=5);
                # columns: Temperature, Pressure, Speed, Direction (C, atm, m/s, Degrees)
                if size(resource) != (8760, 4)
                    @error "Wind Toolkit did not return valid resource data. Got an array with size $(size(resource))"
                end
            catch e
                @error "Error occurred when calling Wind Toolkit: $e"
            end
            push!(resources, resource)
        end
        resources = hcat(resources...)
    end  # done filling in resources (can contain one Vector of Vectors or multiple Vectors of Vectors)

    # Initialize SAM inputs
    global hdl = nothing
    sam_prodfactor = []

    # Corresponding size in kW for generic reference turbines sizes
    system_capacity_lookup = Dict(
        "large"=> 2000,
        "medium" => 250,
        "commercial"=> 100,
        "residential"=> 2.5
    )
    system_capacity = system_capacity_lookup[wind.size_class]
    
    # Corresponding rotor diameter in meters for generic reference turbines sizes
    rotor_diameter_lookup = Dict(
        "large" => 55*2,
        "medium" => 21.9*2,
        "commercial" => 13.8*2,
        "residential" => 1.85*2
    )
    wind_turbine_powercurve_lookup = Dict(
        "large" => [0, 0, 0, 70.119, 166.208, 324.625, 560.952, 890.771, 1329.664,
                    1893.213, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000,
                    2000, 2000, 2000, 2000, 2000, 2000],
        "medium"=> [0, 0, 0, 8.764875, 20.776, 40.578125, 70.119, 111.346375, 166.208,
                    236.651625, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250, 250,
                    250, 250, 250, 250, 250],
        "commercial"=> [0, 0, 0, 3.50595, 8.3104, 16.23125, 28.0476, 44.53855, 66.4832,
                        94.66065, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
                        100, 100, 100, 100, 100],
        "residential"=> [0, 0, 0, 0.070542773, 0.1672125, 0.326586914, 0.564342188,
                        0.896154492, 1.3377, 1.904654883, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5,
                        2.5, 2.5, 2.5, 0, 0, 0, 0, 0, 0, 0]
    )

    try        
        if Sys.isapple() 
            libfile = "libssc.dylib"
        elseif Sys.islinux()
            libfile = "libssc.so"
        elseif Sys.iswindows()
            libfile = "ssc.dll"
        else
            @error """Unsupported platform for using the SAM Wind module. 
                      You can alternatively provide the Wind.prod_factor_series"""
        end

        global hdl = joinpath(dirname(@__FILE__), "..", "sam", libfile)
        wind_module = @ccall hdl.ssc_module_create("windpower"::Cstring)::Ptr{Cvoid}
        wind_resource = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
        @ccall hdl.ssc_module_exec_set_print(0::Cint)::Cvoid

        @ccall hdl.ssc_data_set_number(wind_resource::Ptr{Cvoid}, "latitude"::Cstring, latitude::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(wind_resource::Ptr{Cvoid}, "longitude"::Cstring, longitude::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(wind_resource::Ptr{Cvoid}, "elevation"::Cstring, 0::Cdouble)::Cvoid  # not used in SAM
        @ccall hdl.ssc_data_set_number(wind_resource::Ptr{Cvoid}, "year"::Cstring, 2012::Cdouble)::Cvoid

        heights_array = []  # have to repeat heights for each resource column
        for h in heights_for_sam
            append!(heights_array, repeat([h], 4))
        end
        heights_array = convert(Array{Float64}, heights_array)
        @ccall hdl.ssc_data_set_array(wind_resource::Ptr{Cvoid}, "heights"::Cstring, 
           heights_array::Ptr{Cdouble}, length(heights_array)::Cint)::Cvoid

        # setup column data types: temperature=1, pressure=2, degree=3, speed=4
        fields = collect(repeat(range(1, stop=4), length(heights_for_sam)))
        fields = convert(Array{Float64}, fields)
        @ccall hdl.ssc_data_set_array(wind_resource::Ptr{Cvoid}, "fields"::Cstring, 
            fields::Ptr{Cdouble}, length(fields)::Cint)::Cvoid

        nrows, ncols = size(resources)
        t = [row for row in eachrow(resources)];
        t2 = reduce(vcat, t);
        # the values in python api are sent to SAM as vector (35040) with rows concatenated
        c_resources = [convert(Float64, t2[i]) for i in eachindex(t2)]
        @ccall hdl.ssc_data_set_matrix(wind_resource::Ptr{Cvoid}, "data"::Cstring, c_resources::Ptr{Cdouble}, 
            Cint(nrows)::Cint, Cint(ncols)::Cint)::Cvoid

        data = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
        @ccall hdl.ssc_data_set_table(data::Ptr{Cvoid}, "wind_resource_data"::Cstring, wind_resource::Ptr{Cvoid})::Cvoid
        @ccall hdl.ssc_data_free(wind_resource::Ptr{Cvoid})::Cvoid

        # # can get the same values back with:
        # a = @ccall hdl.ssc_data_get_matrix(wind_resource::Ptr{Cvoid}, "data"::Cstring, Ref(Cint(4))::Ptr{Cint}, Ref(Cint(4))::Ptr{Cint})::Ptr{Cdouble}
        # unsafe_load(a, 1)
        # unsafe_load(a, 35040)

        # Scaler inputs
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_resource_shear"::Cstring, 0.14000000059604645::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_resource_turbulence_coeff"::Cstring, 
            0.10000000149011612::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "system_capacity"::Cstring, 
            system_capacity::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_resource_model_choice"::Cstring, 0::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "weibull_reference_height"::Cstring, 50::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "weibull_k_factor"::Cstring, 2::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "weibull_wind_speed"::Cstring, 7.25::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_turbine_rotor_diameter"::Cstring, 
            rotor_diameter_lookup[wind.size_class]::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_turbine_hub_ht"::Cstring, wind.hub_height::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_turbine_max_cp"::Cstring, 0.44999998807907104::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_farm_losses_percent"::Cstring, 0::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "wind_farm_wake_model"::Cstring, 0::Cdouble)::Cvoid
        @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid}, "adjust:constant"::Cstring, 0::Cdouble)::Cvoid

        # Array inputs
        speeds = convert(Array{Float64},
            [0., 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25])
        @ccall hdl.ssc_data_set_array(data::Ptr{Cvoid}, "wind_turbine_powercurve_windspeeds"::Cstring, 
            speeds::Ptr{Cdouble}, length(speeds)::Cint)::Cvoid
        
        powercurve = convert(Array{Float64}, wind_turbine_powercurve_lookup[wind.size_class])
        @ccall hdl.ssc_data_set_array(data::Ptr{Cvoid}, "wind_turbine_powercurve_powerout"::Cstring, 
            powercurve::Ptr{Cdouble}, length(powercurve)::Cint)::Cvoid
        
        wind_farm_xCoordinates = [Float64(0)]
        @ccall hdl.ssc_data_set_array(data::Ptr{Cvoid}, "wind_farm_xCoordinates"::Cstring, 
            wind_farm_xCoordinates::Ptr{Cdouble}, 1::Cint)::Cvoid
        
        wind_farm_yCoordinates = [Float64(0)]
        @ccall hdl.ssc_data_set_array(data::Ptr{Cvoid}, "wind_farm_yCoordinates"::Cstring, 
            wind_farm_yCoordinates::Ptr{Cdouble}, 1::Cint)::Cvoid

        # example of getting a number:
        # val = convert(Cdouble, 0.0)
        # ref = Ref(val)
        # @ccall hdl.ssc_data_get_number(data::Ptr{Cvoid}, "wind_resource_shear"::Cstring, ref::Ptr{Cdouble})::Cvoid
        # Float64(ref[])
        
        if !Bool(@ccall hdl.ssc_module_exec(wind_module::Ptr{Cvoid}, data::Ptr{Cvoid})::Cint)
            log_type = 0
            log_type_ref = Ref(log_type)
            log_time = 0
            log_time_ref = Ref(log_time)
            msg_ptr = @ccall hdl.ssc_module_log(wind_module::Ptr{Cvoid}, 0::Cint, log_type_ref::Ptr{Cvoid}, 
                                            log_time_ref::Ptr{Cvoid})::Cstring
            msg = "no message from ssc_module_log."
            try
                msg = unsafe_string(msg_ptr)
            finally
                @error("SAM Wind simulation error: $msg")
            end
        end

        len = 0
        len_ref = Ref(len)
        a = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, "gen"::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        for i in range(1, stop=8760)
            push!(sam_prodfactor, unsafe_load(a, i))
        end
        @ccall hdl.ssc_module_free(wind_module::Ptr{Cvoid})::Cvoid   
        @ccall hdl.ssc_data_free(data::Ptr{Cvoid})::Cvoid

    catch e
        @error "Problem calling SAM C library!"
        showerror(stdout, e)
    end

    if !(length(sam_prodfactor) == 8760)
        @error "Wind production factor from SAM has length $(length(sam_prodfactor)) (should be 8760)."
    end

    @assert !(nothing in sam_prodfactor) "Did not get complete Wind production factor from SAM."

    # normalize by system_capacity
    normalized_prod_factor = sam_prodfactor ./ system_capacity
    # upsample if time steps per hour > 1
    if time_steps_per_hour > 1
        normalized_prod_factor = repeat(normalized_prod_factor, inner=time_steps_per_hour)
    end
    return normalized_prod_factor
end
