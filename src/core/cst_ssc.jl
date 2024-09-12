### Script for running any type of SSC module
using JSON
import HTTP
using DelimitedFiles
using DataFrames
using CSV
using Base.Iterators





function set_ssc_data_from_dict(D,model,data)
    j = 0
    for (key, value) in D
        if key == "solar_resource_file"
            continue
        elseif typeof(value) == String
            @ccall hdl.ssc_data_set_string(data::Ptr{Cvoid},key::Cstring,D[key]::Cstring)::Cvoid
            j += 1
        elseif typeof(D[key]) in [Int64,Float64]
            @ccall hdl.ssc_data_set_number(data::Ptr{Cvoid},key::Cstring,D[key]::Cdouble)::Cvoid
            j += 1
        elseif typeof(D[key]) == Vector{Any} || typeof(D[key]) == Vector{Float64} || typeof(D[key]) == Vector{Int64}
            nrows, ncols = length(D[key]), length(D[key][1])
            c_matrix = []
            for k in 1:nrows
                for l in 1:ncols
                    push!(c_matrix,D[key][k][l])
                end
            end
            if ncols == 1 && (nrows > 2 || model == "mst")
                c_matrix = convert(Array{Float64},c_matrix)
                @ccall hdl.ssc_data_set_array(data::Ptr{Cvoid},key::Cstring,c_matrix::Ptr{Cdouble},length(D[key])::Cint)::Cvoid
                j += 1
            else
                c_matrix = convert(Array{Float64},c_matrix)
                @ccall hdl.ssc_data_set_matrix(data::Ptr{Cvoid},key::Cstring,c_matrix::Ptr{Cdouble},Cint(nrows)::Cint,Cint(ncols)::Cint)::Cvoid
                j += 1
            end
        elseif typeof(D[key]) == Dict{Any,Any}
            table = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
            set_ssc_data_from_dict(D[key],model,table)
            @ccall hdl.ssc_data_set_table(data::Ptr{Cvoid}, key::Cstring, table::Ptr{Cvoid})::Cvoid
            @ccall hdl.ssc_data_free(table::Ptr{Cvoid})::Cvoid
        else
            print("Could not assign variable " * key)
        end
        
    end
end

function get_weatherdata(lat::Float64,lon::Float64,debug::Bool)
    ### Call NSRDB
    api_jgifford = "wKt35uq0aWoNHnzuwbcUxElPhVuo0K18YPSgZ9Ph"
    attributes_tmy = "ghi,dhi,dni,wind_speed,wind_direction,air_temperature,surface_pressure,dew_point"
    url = string("http://developer.nrel.gov/api/nsrdb/v2/solar/psm3-2-2-tmy-download.csv?api_key=",api_jgifford,
        "&wkt=POINT(",lon,"%20",lat,")&attributes=",attributes_tmy,
        "&names=tmy&utc=false&leap_day=true&interval=60&email=jeffrey.gifford@nrel.gov")
    # r = HTTP.request("GET", url)
    
    df = DataFrame(CSV.File(HTTP.get(url).body,delim=",",silencewarnings=true))
    
    ### Write csv file for checking (can comment out/delete when not debugging)
    debug = false
    if debug
        weatherfile_string = string("weatherfile_",lat,"_",lon,"_wdir.csv")
        CSV.write(weatherfile_string,df)
    end
    
    ### Create weather data dataframe for SAM
    weatherdata = Dict()
    weatherdata["tz"] = parse(Int64,df."Time Zone"[1])
    weatherdata["elev"] = parse(Float64,df."Elevation"[1])
    weatherdata["lat"] = parse(Float64,df."Latitude"[1])
    weatherdata["lon"] = parse(Float64,df."Longitude"[1])
    new_df = vcat(df[3:end, :])
    weatherdata["year"] = parse.(Int64,new_df."Source") # Source --> year 
    weatherdata["month"] = parse.(Int64,new_df."Location ID") # Location ID --> month
    weatherdata["day"] = parse.(Int64,new_df."City") # City --> day 
    weatherdata["hour"] = parse.(Int64,new_df."State") # State --> hour
    weatherdata["minute"] = parse.(Int64,new_df."Country") # Country --> minute
    weatherdata["dn"] = parse.(Float64,new_df."Time Zone") # Time Zone --> dn (DNI)
    weatherdata["df"] = parse.(Float64,new_df."Longitude") # Longitude --> df (DHI)
    weatherdata["gh"] = parse.(Float64,new_df."Latitude") # Latitude --> gh (GHI)
    weatherdata["wspd"] = parse.(Float64,new_df."Elevation") # Elevation --> wspd
    weatherdata["wdir"] = parse.(Int64,new_df."Local Time Zone") # Local Time Zone --> wdir
    weatherdata["tdry"] = parse.(Float64,new_df."Dew Point Units") # Dew Point Units --> tdry
    weatherdata["tdew"] = parse.(Float64,new_df."DNI Units") # Clearsky DNI Units --> rhum (RH)
    weatherdata["pres"] = parse.(Float64,new_df."DHI Units") # Clearsky DHI Units --> pres
    ### Full list of weather data types (not all are required)
    # (numbers): lat, lon, tz, elev, 
    # (arrays): year, month, day, hour, minute, gh, dn, df, poa, wspd, wdir, tdry, twet, tdew, rhum, pres, snow, alb, aod
    
    return weatherdata
end

function normalize_response(response,case_data,rated_power)
    model = case_data["CST"]["type"]
    if model =="ptc"
        heat_sink = case_data["CST"]["q_pb_design"]
        SM = 2.5
        return response ./ (SM * heat_sink)
    end

end

# function run_ssc(model::String,lat::Float64,lon::Float64,inputs::Dict,outputs::Vector)
function run_ssc(case_data::Dict)
    model = case_data["CST"]["type"]
    ### Maps STEP 1 model names to specific SSC modules
    model_ssc = Dict(
        "mst" => "tcsmolten_salt",
        "swh_flatplate" => "swh",
        "swh_evactube" => "swh",
        "lf" => "linear_fresnel_dsg_iph",
        "ptc" => "trough_physical_iph" #
    ) # relates internal names to specific models in SAM (for example, there are multiple molten salt tower models to pick from in the SSC)
    lat = case_data["Site"]["latitude"]
    lon = case_data["Site"]["longitude"]
    ### User defined inputs needed by technology type
    user_defined_inputs = Dict()
    user_defined_inputs_list = Dict(
        "swh_flatplate" => ["T_set","fluid","ncoll","tilt"],
        "swh_evactube" => ["T_set","fluid","ncoll","tilt"],
        "ptc" => ["Fluid","q_pb_design","T_loop_in_des","T_loop_out","specified_total_aperture","T_tank_hot_inlet_min","use_solar_mult_or_aperture_area","hot_tank_Thtr","cold_tank_Thtr","lat"], # need to add "store_fluid",
        "lf" => [],
        "mst" => ["T_htf_cold_des","T_htf_hot_des","q_pb_design","dni_des","csp.pt.sf.fixed_land_area","land_max","land_min","h_tower","rec_height","rec_htf","cold_tank_Thtr","hot_tank_Thtr"]
    )
    # First set user defined inputs to default just in case
    defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_step1_" * model * ".json") ## TODO update this to step 1 default jsons once they're ready
    defaults = JSON.parsefile(defaults_file)
    for i in user_defined_inputs_list[model]
        user_defined_inputs[i] = defaults[i]
    end
    for i in user_defined_inputs_list[model]
        if (i == "tilt") || (i == "lat")
            user_defined_inputs[i] = lat
        else
            user_defined_inputs[i] = case_data["CST"]["SSC_Inputs"][i]
        end
    end

    R = Dict()
    error = ""
    
    if !(model in collect(keys(model_ssc)))
        error =  error * "Model is not available at this time. \n"
    else
        ### Setup SSC
        global hdl = nothing
        libfile = "ssc.dll"
        global hdl = joinpath(@__DIR__, "sam", libfile)
        ssc_module = @ccall hdl.ssc_module_create(model_ssc[model]::Cstring)::Ptr{Cvoid}
        data = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
        @ccall hdl.ssc_module_exec_set_print(1::Cint)::Cvoid # change to 1 to print outputs/errors (for debugging)

        ### Import defaults
        # defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_" * model_ssc[model] * "_step1.json")
        defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_step1_" * model * ".json")
        defaults = JSON.parsefile(defaults_file)
        set_ssc_data_from_dict(defaults,model,data)

        ### Get weather data
        print_weatherdata = false # True = write a weather data csv file that can be read in the SAM UI # false = skip writing
        weatherdata = get_weatherdata(lat,lon,print_weatherdata)
        user_defined_inputs["solar_resource_data"] = weatherdata

        ### Set inputs
        set_ssc_data_from_dict(user_defined_inputs,model,data)

        ### Execute simulation
        test = @ccall hdl.ssc_module_exec(ssc_module::Ptr{Cvoid}, data::Ptr{Cvoid})::Cint
        print(test)
        ### Retrieve results
        len = 0
        len_ref = Ref(len)
        ### SSC output names for the thermal production and electrical consumption profiles, thermal power rating and solar multiple
        outputs_dict = Dict(
            "mst" => ["Q_thermal","P_tower_pump","q_pb_design","solarm"],         # locked in [W]
            "lf" => ["q_dot_to_heat_sink"], # locked in [W]
            "ptc" => ["q_dot_htf_sf_out","P_loss","q_pb_design",2.5],  # locked in [MWt]
            "swh_flatplate" => ["Q_useful","load","system_capacity",1.0],           # W
            "swh_evactube" => ["Q_useful","load","system_capacity",1.0]           # W
        )
        outputs = outputs_dict[model]

        thermal_production_response = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs[1]::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        electrical_consumption_response = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs[2]::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        thermal_production = []
        elec_consumption = []
        for i in 1:8760
            push!(thermal_production,unsafe_load(thermal_production_response,i))  # For array type outputs
            push!(elec_consumption,unsafe_load(electrical_consumption_response,i))  # For array type outputs
        end
        if outputs[3] in keys(user_defined_inputs)
            tpow = user_defined_inputs[outputs[3]]
        else
            tpow = defaults[outputs[3]]
        end
        if typeof(outputs[4]) != String
            mult = outputs[4]
        elseif outputs[4] in keys(user_defined_inputs)
            mult = user_defined_inputs[outputs[4]]
        else
            mult = defaults[outputs[4]]
        end
        println("tpow ", tpow, " mult ", mult)
        rated_power = tpow * mult
        
        #c_response = @ccall hdl.ssc_data_get_number(data::Ptr{Cvoid}, k::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        # print(c_response)
        thermal_production_norm = thermal_production ./ rated_power # normalize_response(thermal_production_response,case_data,rated_power)
        electric_consumption_norm = elec_consumption ./ rated_power
        # R[k] = response_norm
        # end
        println(thermal_production_norm[1:100])
        println(electric_consumption_norm[1:100])
        ### Free SSC
        @ccall hdl.ssc_module_free(ssc_module::Ptr{Cvoid})::Cvoid   
        @ccall hdl.ssc_data_free(data::Ptr{Cvoid})::Cvoid
        R["thermal_production"] = thermal_production_norm
        R["electric_consumption"] = electric_consumption_norm
        ### Check for errors
        if error == ""
            error = "No errors found."
        end
        R["error"] = error
        #return R
    end
    return R
end
