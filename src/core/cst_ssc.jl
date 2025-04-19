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
    api_jgifford = "IOEFhaZoaOxkB2l9XvkaFswXgTsJxRqob1hBbPdv"
    # attributes_tmy_updated = "ghi,dhi,dni,wind_speed,wind_direction,air_temperature,surface_pressure,dew_point" #for tmy
    attributes_tmy_updated = "ghi,dhi,dni,wind_speed,wind_direction,air_temperature,surface_pressure,dew_point" #for tmy
    url = string("http://developer.nrel.gov/api/nsrdb/v2/solar/psm3-2-2-tmy-download.csv?api_key=",api_jgifford,
        "&wkt=POINT(",lon,"%20",lat,")&attributes=",attributes_tmy_updated,
        "&names=tmy&utc=false&leap_day=true&interval=60&email=jeffrey.gifford@nrel.gov")
    r = HTTP.request("GET", url)
    s = String(r.body)
    lead_df = DataFrame(CSV.File(IOBuffer(s), silencewarnings = true, delim=",", header=1, limit=1))
    df = DataFrame(CSV.File(IOBuffer(s), silencewarnings = true, delim=",", header=3))
    
    ### Write csv file for checking (can comment out/delete when not debugging)
    debug = false
    if debug
        weatherfile_string = string("weatherfile_",lat,"_",lon,"_wdir.csv")
        CSV.write(weatherfile_string,df)
    end
    
    ### Create weather data dataframe for SAM
    weatherdata = Dict()

    weatherdata["tz"] = lead_df."Time Zone"[1]
    weatherdata["elev"] = lead_df."Elevation"[1]
    weatherdata["lat"] = lead_df."Latitude"[1]
    weatherdata["lon"] = lead_df."Longitude"[1]
    weatherdata["year"] = df."Year" # Source --> year 
    weatherdata["month"] = df."Month" # Location ID --> month
    weatherdata["day"] = df."Day" # City --> day 
    weatherdata["hour"] = df."Hour" # State --> hour
    weatherdata["minute"] = df."Minute" # Country --> minute
    weatherdata["dn"] = df."DNI" # Time Zone --> dn (DNI)
    weatherdata["df"] = df."DHI" # Longitude --> df (DHI)
    weatherdata["gh"] = df."GHI" # Latitude --> gh (GHI)
    weatherdata["wspd"] = df."Wind Speed" # Elevation --> wspd
    weatherdata["wdir"] = df."Wind Direction" # Local Time Zone --> wdir
    weatherdata["tdry"] = df."Temperature" # Dew Point Units --> tdry
    weatherdata["tdew"] = df."Dew Point" # Clearsky DNI Units --> rhum (RH)
    weatherdata["pres"] = df."Pressure" # Clearsky DHI Units --> pres
    ### Full list of weather data types (not all are required)
    # (numbers): lat, lon, tz, elev, 
    # (arrays): year, month, day, hour, minute, gh, dn, df, poa, wspd, wdir, tdry, twet, tdew, rhum, pres, snow, alb, aod
    
    return weatherdata
end

function normalize_response(thermal_power_produced,case_data,user_defined_inputs)
    model = case_data["CST"]["tech_type"]
    if model =="ptc"
        heat_sink = user_defined_inputs["q_pb_design"]
        rated_power_per_area = 39.37 / 60000.0 # MWt / m2, TODO: update with median values from SAM params
        if user_defined_inputs["use_solar_mult_or_aperture_area"] > 0
            rated_power = rated_power_per_area * user_defined_inputs["specified_total_aperture"]
        else
            rated_power = user_defined_inputs["specified_solar_multiple"] * heat_sink
        end
    elseif model=="mst"
        heat_sink = case_data["CST"]["SSC_Inputs"]["q_pb_design"]
        rated_power = 3.0 * heat_sink
    else
        rated_power = 1.0 #not actually normalization
    end
    thermal_power_produced_norm = thermal_power_produced ./ (rated_power) 
    thermal_power_produced_norm[thermal_power_produced_norm .< 0] .= 0  # remove negative values
    return thermal_power_produced_norm
end

# function run_ssc(model::String,lat::Float64,lon::Float64,inputs::Dict,outputs::Vector)
function run_ssc(case_data::Dict)
    model = case_data["CST"]["tech_type"]
    ### Maps STEP 1 model names to specific SSC modules
    model_ssc = Dict(
        "mst" => "mspt_iph",
        "swh_flatplate" => "swh",
        "swh_evactube" => "swh",
        "lf" => "fresnel_physical_iph",
        "ptc" => "trough_physical_iph" #
    ) # relates internal names to specific models in SAM (for example, there are multiple molten salt tower models to pick from in the SSC)
    lat = case_data["Site"]["latitude"]
    lon = case_data["Site"]["longitude"]
    ### User defined inputs needed by technology type
    user_defined_inputs = Dict()
    user_defined_inputs_list = Dict(
        "swh_flatplate" => ["T_set","fluid","ncoll","tilt"],
        "swh_evactube" => ["T_set","fluid","ncoll","tilt"],
        "ptc" => [], # need to add "store_fluid",
        "lf" => [],
        "mst" => ["T_htf_cold_des","T_htf_hot_des","q_pb_design","dni_des","csp.pt.sf.fixed_land_area","land_max","land_min","h_tower","rec_height","rec_htf","cold_tank_Thtr","hot_tank_Thtr"]
    )
    # First set user defined inputs to default just in case
    defaults_file = joinpath(@__DIR__,"..","sam","defaults","defaults_" * model_ssc[model] * "_step1.json") ## TODO update this to step 1 default jsons once they're ready
    defaults = JSON.parsefile(defaults_file)
    if model in ["swh_flatplate","swh_evactube"]
        scaled_draw_filename = joinpath(@__DIR__,"sam","defaults","scaled_draw_500000_kg_per_day.csv")
        scaled_draw_df = CSV.read(scaled_draw_filename, DataFrame; header=false)
        scaled_draw_values = scaled_draw_df[:, 1]
        defaults["scaled_draw"] = scaled_draw_values
    end
    println("Defaults loaded.")
    defaults["file_name"] = joinpath(@__DIR__,"sam","defaults","tucson_az_32.116521_-110.933042_psmv3_60_tmy.csv") #update default weather file path to local directory
    if haskey(case_data["CST"], "SSC_Inputs")
        for i in user_defined_inputs_list[model]
            if (i == "tilt") || (i == "lat")
                user_defined_inputs[i] = lat
            end
        end
        for i in keys(case_data["CST"]["SSC_Inputs"])
            user_defined_inputs[i] = case_data["CST"]["SSC_Inputs"][i]
        end
    else
        if model != "ptc"
            R["error"] = "SSC_Inputs must be provided for your provided CST tech type"
            return R
        end
    end
    if model == "ptc"
        if haskey(case_data["CST"], "inlet_temp_degF") && haskey(case_data["CST"], "outlet_temp_degF")
            inlet_temp = case_data["CST"]["inlet_temp_degF"]
            outlet_temp = case_data["CST"]["outlet_temp_degF"]
            user_defined_inputs["h_tank_in"] = defaults["h_tank"]
            user_defined_inputs["f_htfmin"] = 0.0
            user_defined_inputs["f_htfmax"] = 1.0
            if !haskey(user_defined_inputs, "T_loop_in_des")
                user_defined_inputs["T_loop_in_des"] = inlet_temp
            end
            if !haskey(user_defined_inputs, "T_loop_out")
                user_defined_inputs["T_loop_out"] = outlet_temp
            end
            if !haskey(user_defined_inputs, "T_tank_hot_inlet_min")
                user_defined_inputs["T_tank_hot_inlet_min"] = outlet_temp - 50
            end
            if !haskey(user_defined_inputs, "hot_tank_Thtr")
                user_defined_inputs["hot_tank_Thtr"] = outlet_temp - 10
            end
            if !haskey(user_defined_inputs, "cold_tank_Thtr")
                user_defined_inputs["cold_tank_Thtr"] = inlet_temp - 10
            end
            if !haskey(user_defined_inputs, "lat")
                user_defined_inputs["lat"] = lat
            end
            if !haskey(user_defined_inputs, "Fluid")
                user_defined_inputs["Fluid"] = 21
            end
            if !haskey(user_defined_inputs, "q_pb_design")
                if haskey(case_data["ProcessHeatLoad"], "fuel_loads_mmbtu_per_hour")
                    user_defined_inputs["q_pb_design"] = maximum(case_data["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"]) * 0.293071
                else
                    user_defined_inputs["q_pb_design"] = 5.2
                end
            end
            if !haskey(user_defined_inputs, "use_solar_mult_or_aperture_area")
                if haskey(case_data["Site"], "land_acres")
                    user_defined_inputs["use_solar_mult_or_aperture_area"] = 1
                    user_defined_inputs["specified_total_aperture"] = case_data["Site"]["land_acres"] * 4046.85642
                else
                    user_defined_inputs["use_solar_mult_or_aperture_area"] = 0
                    user_defined_inputs["specified_solar_multiple"] = 2.5
                end
            end
        end
    end
    R = Dict()
    error = ""
    
    if !(model in collect(keys(model_ssc)))
        error =  error * "Model is not available at this time. \n"
    else
        ### Setup SSC
        global hdl = nothing
        #libfile = "ssc_new.dll"
        if Sys.isapple() 
            libfile = "libssc.dylib"
        elseif Sys.islinux()
            libfile = "ssc.so"
        elseif Sys.iswindows()
            libfile = "ssc_new.dll"
        end
        global hdl = joinpath(@__DIR__, "..", "sam", libfile)
        chmod(hdl, filemode(hdl) | 0o755) ### added just because I saw this in the wind module
        ssc_module = @ccall hdl.ssc_module_create(model_ssc[model]::Cstring)::Ptr{Cvoid}
        data = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
        @ccall hdl.ssc_module_exec_set_print(1::Cint)::Cvoid # change to 1 to print outputs/errors (for debugging)

        ### Set defaults
        set_ssc_data_from_dict(defaults,model,data)
        ### Get weather data
        print_weatherdata = false # True = write a weather data csv file that can be read in the SAM UI # false = skip writing
        weatherdata = get_weatherdata(lat,lon,print_weatherdata)
        user_defined_inputs["solar_resource_data"] = weatherdata
        ### Set inputs
        set_ssc_data_from_dict(user_defined_inputs,model,data)
        ### Execute simulation
        test = @ccall hdl.ssc_module_exec(ssc_module::Ptr{Cvoid}, data::Ptr{Cvoid})::Cint
        ### Retrieve results
        ### SSC output names for the thermal production and electrical consumption profiles, thermal power rating and solar multiple
        outputs_dict = Dict(
            "mst" => ["Q_thermal","P_tower_pump",0.0,"q_pb_design","solarm"],         # Q_thermal = [MWt] (confirmed 1/14/2025)
            "lf" => ["q_dot_htf_sf_out","W_dot_heat_sink_pump","W_dot_parasitic_tot","q_pb_design",1.0], # locked in [W]
            "ptc" => ["q_dot_htf_sf_out","P_loss",0.0,"q_pb_design",3.0],  # q_dot_htf_sf_out = [MWt] (confirmed 1/14/2025)
            "swh_flatplate" => ["Q_useful","P_pump",0.0,"system_capacity",1.0],           # Q_useful = [kWt] confirmed 1/14/2025)
            "swh_evactube" => ["Q_useful","P_pump",0.0,"system_capacity",1.0]           # Q_useful = [kWt] confirmed 1/14/2025), kW, kW, kW
        )
        thermal_conversion_factor = Dict(
            "mst" => 1,         
            "lf" => 1, 
            "ptc" => 1,  
            "swh_flatplate" => 1,          
            "swh_evactube" => 1           
        ) 
        elec_conversion_factor = Dict(
            "mst" => 1,   
            "lf" => 1, 
            "ptc" => 1,  
            "swh_flatplate" => 1,           
            "swh_evactube" => 1           
        ) 
        outputs = outputs_dict[model]
        println("retrieved outputs")
        
        len = 8760
        len_ref = Ref(len)
        thermal_production_response = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs[1]::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        # electrical_consumption_response = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs[2]::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}    
        thermal_production = []
        # elec_consumption = []
        # return
        for i in 1:8760
            push!(thermal_production,unsafe_load(thermal_production_response,i))  # For array type outputs
            # push!(thermal_production,1.0) #for pass through
            # push!(elec_consumption,unsafe_load(electrical_consumption_response,i))  # For array type outputs
        end
        thermal_production[thermal_production .< 0] .= 0 #removes negative values
        # if typeof(outputs[3]) == String
        #     secondary_consumption_response =  @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs[3]::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}    
        #     for i in 1:8760
        #         elec_consumption[i] += unsafe_load(secondary_consumption_response, i)
        #     end
        # end
        if outputs[4] in keys(user_defined_inputs)
            tpow = user_defined_inputs[outputs[4]]
        else
            tpow = defaults[outputs[4]]
        end
        if typeof(outputs[5]) != String
            mult = outputs[5]
        elseif outputs[5] in keys(user_defined_inputs)
            mult = user_defined_inputs[outputs[5]]
        else
            mult = defaults[outputs[5]]
        end
        rated_power = tpow * mult
        
        tcf = thermal_conversion_factor[model]
        ecf = elec_conversion_factor[model]
        #c_response = @ccall hdl.ssc_data_get_number(data::Ptr{Cvoid}, k::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        # print(c_response)
        ## TODO: DO WE NEED THIS FUNCTION/IF STATEMENT ANYMORE??
        if model == "ptc"
            thermal_production_norm = normalize_response(thermal_production, case_data, user_defined_inputs)
        else
            thermal_production_norm = thermal_production .* tcf ./ rated_power
        end
        if model in ["mst","ptc","lf"]
            println("Maximum annual thermal energy collected by CST: " * string(round(sum(thermal_production),digits=2)) * " MWht.")
        elseif model in ["swh_evactube","swh_flatplate"]
            println("Maximum annual thermal energy collected by solar water heater: " * string(round(sum(thermal_production),digits=2)) * " kWht.")
        end
        electric_consumption_norm = zeros(8760) #elec_consumption .* ecf ./ rated_power
        ### Free SSC
        @ccall hdl.ssc_module_free(ssc_module::Ptr{Cvoid})::Cvoid   
        @ccall hdl.ssc_data_free(data::Ptr{Cvoid})::Cvoid

        R["thermal_production_series"] = thermal_production_norm
        R["electric_consumption_series"] = electric_consumption_norm
        ### Check for errors
        if error == ""
            error = "No errors found."
        end
        R["error"] = error
        #return R
    end
    return R
end
