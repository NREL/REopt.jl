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
    defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_" * model_ssc[model] * ".json") ## TODO update this to step 1 default jsons once they're ready
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
        libfile = "ssc_new.dll"
        global hdl = joinpath(@__DIR__, "sam", libfile)
        ssc_module = @ccall hdl.ssc_module_create(model_ssc[model]::Cstring)::Ptr{Cvoid}
        data = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
        @ccall hdl.ssc_module_exec_set_print(1::Cint)::Cvoid # change to 1 to print outputs/errors (for debugging)

        ### Import defaults
        defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_" * model_ssc[model] * "_step1.json")
        # defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_step1_" * model * ".json")
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
        ### SSC output name for the thermal production profile
        outputs_dict = Dict(
            "mst" => ["Q_thermal"],         # locked in [W]
            "lf" => ["q_dot_to_heat_sink"], # locked in [W]
            "ptc" => "q_dot_htf_sf_out",  # locked in [MWt]
            "swh_flatplate" => ["Q_useful"],           # W
            "swh_evactube" => ["Q_useful"]           # W
        )
        outputs = outputs_dict[model]
        thermal_production_response = @ccall hdl.ssc_data_get_array(data::Ptr{Cvoid}, outputs::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        thermal_production = []
        for i in 1:8760
            push!(thermal_production,unsafe_load(thermal_production_response,i))  # For array type outputs
        end
        # print(thermal_production)
        if model == "ptc"
            # @ccall hdl.ssc_data_get_number(data::Ptr{Cvoid}, "wind_resource_shear"::Cstring, ref::Ptr{Cdouble})::Cvoid
            heat_sink = case_data["CST"]["SSC_Inputs"]["q_pb_design"]
            sm = 2.5
            rated_power = heat_sink * sm
        end
        
        #c_response = @ccall hdl.ssc_data_get_number(data::Ptr{Cvoid}, k::Cstring, len_ref::Ptr{Cvoid})::Ptr{Float64}
        # print(c_response)
        
        # #print(response)
        thermal_production_norm = thermal_production ./ rated_power # normalize_response(thermal_production_response,case_data,rated_power)
        # R[k] = response_norm
        # end

        ### Free SSC
        @ccall hdl.ssc_module_free(ssc_module::Ptr{Cvoid})::Cvoid   
        @ccall hdl.ssc_data_free(data::Ptr{Cvoid})::Cvoid

    end
    
    ### Check for errors
    if error == ""
        error = "No errors found."
    end
    R["error"] = error
    #return R
    return thermal_production_norm
end

# function get_user_defined_inputs_for_cst(model::String)
#     user_defined_inputs = Dict()
#     user_defined_inputs_list = Dict(
#         "swh_flatplate" => ["T_set","fluid","ncoll","tilt"],
#         "swh_evactube" => ["T_set","fluid","ncoll","tilt"],
#         "ptc" => ["Fluid","q_bp_design","T_loop_in_des","T_loop_out","specified_total_aperture","T_tank_hot_inlet_min","use_solar_mult_or_aperture_area","hot_tank_Thtr","cold_tank_Thtr","store_fluid","lat"],
#         "lf" => [],
#         "mst" => ["T_htf_cold_des","T_htf_hot_des","q_bp_design","dni_des","csp.pt.sf.fixed_land_area","land_max","land_min","h_tower","rec_height","rec_htf","cold_tank_Thtr","hot_tank_Thtr"]
#     )

#     defaults_file = joinpath(@__DIR__,"sam","defaults","defaults_" * model * ".json") ## TODO update this to step 1 default jsons once they're ready
#     defaults = JSON.parsefile(defaults_file)
#     for i in user_defined_inputs_list[model]
#         user_defined_inputs[i] = defaults[i]
#         if i == "ncoll"
#             user_defined_inputs[i] = 20
#         end
#     end

#     return user_defined_inputs
# end

# model = "swh_flatplate"
# user_defined_inputs = get_user_defined_inputs_for_cst(model)

### Test case list
# Define the dictionary with cities as keys and latitudes/longitudes as arrays
cities_dict = Dict(
    # "New York City, NY" => [40.7128, -74.0060],
    # "Los Angeles, CA" => [34.0522, -118.2437],
    # "Chicago, IL" => [41.8781, -87.6298],
    # "Houston, TX" => [29.7604, -95.3698],
    # "Miami, FL" => [25.7617, -80.1918],
    # "Seattle, WA" => [47.6062, -122.3321],
    "Denver, CO" => [39.7392, -104.9903],
    # "Atlanta, GA" => [33.7490, -84.3880],
    # "Boston, MA" => [42.3601, -71.0589],
    # "San Francisco, CA" => [37.7749, -122.4194],
    # "Phoenix, AZ" => [33.4484, -112.0740],
    # "Philadelphia, PA" => [39.9526, -75.1652],
    # "San Antonio, TX" => [29.4241, -98.4936],
    # "San Diego, CA" => [32.7157, -117.1611],
    # "Dallas, TX" => [32.7767, -96.7970],
    # "Portland, OR" => [45.5051, -122.6750],
    # "Detroit, MI" => [42.3314, -83.0458],
    # "Minneapolis, MN" => [44.9778, -93.2650],
    # "Tampa, FL" => [27.9506, -82.4572],
    # "Charlotte, NC" => [35.2271, -80.8431],
    # "New Orleans, LA" => [29.9511, -90.0715],
    # "Raleigh, NC" => [35.7796, -78.6382],
    # "Salt Lake City, UT" => [40.7608, -111.8910],
    # "Indianapolis, IN" => [39.7684, -86.1581],
    # "San Jose, CA" => [37.3382, -121.8863],
    # "Columbus, OH" => [39.9612, -82.9988],
    # "Las Vegas, NV" => [36.1699, -115.1398],
    # "Austin, TX" => [30.2500, -97.7500],
    # "Nashville, TN" => [36.1627, -86.7816],
    # "Pittsburgh, PA" => [40.4406, -79.9959],
    # "St. Louis, MO" => [38.6270, -90.1994],
    # "Portland, ME" => [43.6591, -70.2568],
    # "Albuquerque, NM" => [35.0844, -106.6504],
    # "Louisville, KY" => [38.2527, -85.7585],
    # "Memphis, TN" => [35.1495, -90.0490],
    # "Buffalo, NY" => [42.8802, -78.8782],
    # "Madison, WI" => [43.0731, -89.4012],
    # "Harrisburg, PA" => [40.2732, -76.8867],
    # "Boise, ID" => [43.6150, -116.2023]
)
#   "Anchorage, AK" => [61.0160, -149.7375], This latitude and longitude produces an error when calling NSRDB:
#   "inputs":{"body":{},"params":{},"query":{"wkt":"POINT(-149.7375 61.016)","attributes":"ghi,dhi,dni,wind_speed,air_temperature,surface_pressure,dew_point","names":"tmy","utc":"false","leap_day":"true","interval":"60","email":"jeffrey.gifford@nrel.gov"}},"metadata":{"version":"2.0.0"},"status":400,"errors":["No data available at the provided location","Data processing failure."]}""") )
#   Need to be able to handle incorrect/unavaiable latitudes and longitudes

# model = "mst" # DONE
# model = "ptc" # DONE
# model = "lf"
# model = "swh"


# ### Outputs wanted (8760 thermal production profiles)
# outputs_dict = Dict(
#     "mst" => ["Q_thermal"],         # locked in [W]
#     "lf" => ["q_dot_to_heat_sink"], # locked in [W]
#     "ptc" => ["q_dot_rec_abs"],     # locked in [W]
#     "swh_flatplate" => ["Q_useful"],           # W
#     "swh_evactube" => ["Q_useful"]           # W
# )

# ### System design capacity variable names
# Q_dict = Dict(
#     "mst" => "P_ref",
#     "ptc" => "q_pb_design",
#     "lf" => "q_pb_design",
#     "swh_flatplate" => "system_capacity",
#     "swh_evactube" => "system_capacity"
# )

### Testing mst, ptc, lf, swh-fp, swh-et


# using Plots

# # Function to normalize each array by its first value
# function normalize_values(values)
#     return values ./ values[1]
# end


### Testing swh model
model = "swh_flatplate" #works
model = "ptc_v3"

# R = Dict()
# for (key, value) in cities_dict
#     inputs = get_user_defined_inputs_for_cst(model)
#     msg = "Began calculation for " * key * ".\n"
#     print(msg)
#     R[string(key)] = sum(run_ssc(model,value[1],value[2],inputs,outputs_dict[model]))
#     print(R)
#     #R[string(key)] = run_ssc(model,value[1],value[2],inputs,outputs_dict[model])
# end


case_file_path = joinpath(@__DIR__,"test_udi_" * model * ".json")
case_data = JSON.parsefile(case_file_path)
R = Dict()
for (key, value) in cities_dict
    case_data["Site"]["latitude"] = value[1]
    case_data["Site"]["longitude"] = value[2]
    R[string(key)] = run_ssc(case_data)
end
# print(R)
    #R[string(key)] = run_ssc(model,value[1],value[2],inputs,outputs_dict[model])

### Test all models
# models = ["mst","ptc","lf","swh_flatplate","swh_evactube"]
# R_all = Dict()
# for m in models
#     R_model = Dict()
#     for (key, value) in cities_dict
#         inputs = Dict()
#         # if m in ["swh_flatplate","swh_evactube"]
#         #     Q = 10000.0 # kWt
#         # else
#         #     Q = 10.0    # MWt
#         # end
#         # inputs[string(Q_dict[m])] = Q
#         # if m in ["mst"]
#         #     inputs["tshours"] = 10000.00
#         # end
#         # user_inputs = Dict{Any,Any}(
#         #     "T_set" => 90.0
#         # )
#         msg = "Began calculation for model: " * m * ", for location: " * string(key) * ".\n"
#         print(msg)
#         R_model[string(key)] = run_ssc(m,value[1],value[2],inputs,outputs_dict[m])
#     end
#     R_all[m] = R_model
# end
# #print(R_all)

using Plots

plot([1:120],R["Denver, CO"][4001:4120])
print(maximum(R["Denver, CO"]))
writedlm( "FileName.csv",  R["Denver, CO"], ',')


# ### Plot results
# x = [1:48]
# #plot(x, R_all["mst"]["Denver, CO"], label="Denver")

# titles = Dict(
#     "mst" => "MS Tower",
#     "ptc" => "Trough",
#     "lf" => "Linear Fresnel",
#     "swh_flatplate" => "Flat Plate",
#     "swh_evactube" => "Evacuated Tube"
# )
# for m in models
#     p = plot()
#     for (key, value) in cities_dict
#         plot!([4128:4175],R_all[m][key][4128:4175]/maximum(R_all[m][key]),label=key,ylabel="Normalized Thermal Production",ylimits=(0,1),xlimits=(4128,4175),xticks=(4128:24:4175,["June 21","June 22"]),title=titles[m])
#     end
#     filename = "test_" * m * "_latest.png"
#     savefig(filename)
# end
# print("done")

# ### Testing lf model
# R = Dict()
# for (key, value) in cities_dict
#     inputs = Dict()
#     inputs["q_pb_des"] = 100 # Heat sink power [MWt]
#     inputs["T_cold_ref"] = 20 # Inlet feed water temperature [C]
#     msg = "Began calculation for " * key * ".\n"
#     print(msg)
#     R[string(key)] = sum(run_ssc(model,value[1],value[2],inputs,outputs_dict[model]))
#     print(R)
#     #R[string(key)] = run_ssc(model,value[1],value[2],inputs,outputs_dict[model])
# end


# # Plot each array after normalization
# plot()
# for (city, values) in R_all_ptc
#     # normalized_values = normalize_values(values)
#     normalized_values = normalize_values(values)
#     plot!(tshours,normalized_values, label=city)
# end

# xlabel!("tshours [hrs]")
# ylabel!("Normalized Annual Production")
# #xtick_labels = ["Label1", "Label2", "Label3", "Label4", "Label5"]  # Replace with your predefined labels
# xticks!(tshours)

# ### Saved results for mst (annual Q_thermal for 10, 50, 100, and 200 hours of storage)
# R_all_mst = Dict(
#     "Los Angeles, CA" => Any[1.40308e6, 1.40318e6, 1.40313e6, 1.38696e6],
#     "Phoenix, AZ" => Any[1.58181e6, 1.58167e6, 1.58197e6, 1.55571e6],
#     "Detroit, MI" => Any[8.24404e5, 8.24312e5, 8.24468e5, 8.15586e5],
#     "Minneapolis, MN" => Any[8.54275e5, 8.54197e5, 8.54302e5, 8.47735e5],
#     "Indianapolis, IN" => Any[8.13746e5, 8.13616e5, 8.13701e5, 8.07885e5],
#     "Atlanta, GA" => Any[968260.0448712073, 968144.782037595, 968307.4199058872, 964254.2289227508],
#     "Dallas, TX" => Any[1.0925878501565722e6, 1.0924508051831862e6, 1.0926674456971062e6, 1.0879812232061303e6],
#     "San Francisco, CA" => Any[1.2508394324339547e6, 1.250696689986322e6, 1.250943448933343e6, 1.2376600860929997e6],
#     "Seattle, WA" => Any[726643.1648777898, 726574.2235940382, 726673.677674925, 714829.1299904337],
#     "Miami, FL" => Any[1.0506013415409853e6, 1.0505945669958878e6, 1.0506350296414904e6, 1.0493701530865352e6],
#     "San Diego, CA" => Any[1.2649100509684752e6, 1.2646694396621832e6, 1.2650345038168714e6, 1.2562292518997956e6],
#     "Portland, OR" => Any[755243.2319479032, 755163.3888052455, 755502.1910594602, 742226.3560221693],
#     "Las Vegas, NV" => Any[1.5700441966960868e6, 1.570072030171488e6, 1.570207571999681e6, 1.5299405721510695e6],
#     "Pittsburgh, PA" => Any[776941.2144719358, 776829.9429598066, 776923.5119451056, 771908.8216057755],
#     "Raleigh, NC" => Any[959838.7717533663, 959740.5006232535, 959875.0569901869, 956455.4558814238],
#     "Denver, CO" => Any[1.2151786500724284e6, 1.2152609140184233e6, 1.2153526343761447e6, 1.191430222510342e6],
#     "Charlotte, NC" => Any[1.0074759898605348e6, 1.0071159150553216e6, 1.0075018063617875e6, 1.0041609696000502e6],
#     "Columbus, OH" => Any[778903.36132267, 778902.4196476957, 778867.6673905605, 773859.5649834782],
#     "Memphis, TN" => Any[991229.2200333574, 990880.5463426296, 991260.9452659818, 986221.6872904205],
#     "Madison, WI" => Any[827588.9050210402, 827506.8846686046, 827544.5099929047, 818656.618720928],
#     "Nashville, TN" => Any[847864.5300991356, 847798.6768606313, 847889.1515386964, 844591.9176441531],
#     "St. Louis, MO" => Any[947436.0970869402, 947513.003895853, 947402.581555659, 943803.6678797107],
#     "San Jose, CA" => Any[1.3728275568068821e6, 1.3726984751884546e6, 1.3729537056397968e6, 1.35158548102865e6],
#     "New Orleans, LA" => Any[981411.6309484018, 981306.4048592164, 981468.5332052868, 978900.9373320685],
#     "New York City, NY" => Any[812486.4196405114, 812422.2842584356, 812512.0231491684, 807677.5195013894],
#     "Philadelphia, PA" => Any[888638.0067642848, 888675.6914323553, 888625.0538451046, 882651.2568267188],
#     "Boston, MA" => Any[900515.2456563017, 900414.969376687, 900555.803373782, 891710.0187333254],
#     "Tampa, FL" => Any[1.1154380584871252e6, 1.1153243077291276e6, 1.1154893681696232e6, 1.1136174877383974e6],
#     "Salt Lake City, UT" => Any[1.1755995117018553e6, 1.1754812773657097e6, 1.1757336546788025e6, 1.1373626860457696e6],
#     "Portland, ME" => Any[830633.49907085, 830644.5669896146, 830655.0309412004, 821901.5013073307],
#     "Chicago, IL" => Any[800399.2890459398, 800407.8177642439, 800418.5981718954, 794230.6003221341],
#     "San Antonio, TX" => Any[1.0885731618937852e6, 1.088443779289186e6, 1.0886031966568376e6, 1.082942245296347e6],
#     "Albuquerque, NM" => Any[1.521244232470021e6, 1.5211098661485843e6, 1.5212440005784603e6, 1.4708791752328365e6],
#     "Louisville, KY" => Any[884701.8433758207, 884831.1465532631, 884611.1946657351, 881417.7962222458],
#     "Austin, TX" => Any[1.090557091825693e6, 1.090612836875267e6, 1.0905982767611314e6, 1.0818161961650215e6],
#     "Buffalo, NY" => Any[723453.0989842182, 723492.1996558083, 723486.6477784899, 714732.1247508705],
#     "Boise, ID" => Any[1.178781421423446e6, 1.1786899048976223e6, 1.179005034106047e6, 1.1365244128980255e6],
#     "Harrisburg, PA" => Any[810523.0262150108, 810237.768417439, 810494.4143170207, 804167.5954751121],
#     "Houston, TX" => Any[950140.4583639399, 950003.5572771668, 950224.9912702986, 947140.3158505545]
# )

# ### Saved results for ptc (annual q_dot_rec_abs) for LinRange(10,100,10) hours of storage (tshours)
# R_all_ptc = Dict(
#     "Denver, CO" => Any[24282.58601044816, 24282.679107724784, 24066.43416733772, 24282.483507429948, 24282.53576447267, 24241.87877746605, 24281.580623725786, 24281.51808787907, 24282.634383460612, 22902.86749657411],
#     "Chicago, IL" => Any[17198.564195996853, 17198.649572340317, 17173.230939686626, 17198.47232886221, 17198.518958344925, 17198.300062653292, 17198.421108184455, 17198.362897875435, 17198.607895305555, 16466.88339454982],
#     "Atlanta, GA" => Any[20746.905433074964, 20747.002649388447, 20714.073630304476, 20746.80077002088, 20746.853661813733, 20746.604146483012, 20746.742173559003, 20746.67821813994, 20746.954797185266, 20197.045754761828],
#     "San Francisco, CA" => Any[25621.0591415449, 25621.150069299274, 25292.388001106352, 25620.96212551289, 25621.012248000297, 25507.52265496661, 25620.909338532896, 25605.629222100248, 25621.103035725486, 24105.744945239],
#     "Houston, TX" => Any[21360.669547246653, 21360.762708612296, 21350.4647414945, 21360.634870100468, 21360.688205263177, 21360.49307507323, 21360.576227831014, 21360.5151781052, 21360.71596055042, 20912.206554499782],
#     "Los Angeles, CA" => Any[28538.361864005987, 28538.4489835122, 28063.826500156327, 28538.26370035794, 28538.312907119325, 28320.69382475999, 28515.839009069736, 28426.943065221836, 28538.405768008364, 26491.346865437437],
#     "Miami, FL" => Any[23955.07198940873, 23955.79969909162, 23954.751959000467, 23954.967047063776, 23955.021030150383, 23954.832588221525, 23954.91202590705, 23954.897743694004, 23955.216926063014, 23423.270441152832],
#     "New York City, NY" => Any[17030.040268121196, 17030.086334722866, 17021.704899677065, 17029.939889357585, 17029.992176520358, 17029.752850452394, 17029.88321185612, 17029.821999492582, 17030.044565875956, 16654.356608122253],
#     "Seattle, WA" => Any[15266.552236319285, 15266.619531688953, 15159.776347975927, 15266.46869594339, 15266.512336755299, 15266.305663713087, 15266.419217703875, 15266.364968138805, 15266.592322471377, 14481.858780951039],
#     "Boston, MA" => Any[18191.46282998004, 18190.90663236379, 18131.837295591966, 18191.36414152714, 18191.413484281562, 18191.18002730531, 18191.30740044445, 18191.246045342086, 18190.86305265445, 17437.385310389967]
#     )


### Testing international data calling
# inputs = Dict()
# inputs["tshours"] = 12.0 # for mst and ptc
# # lat = -25.0
# # lon = 133.0
# model = "mst"
# R[string(t)] = sum(run_ssc(model,lat,lon,inputs,outputs_dict[model]))


# tshours = LinRange(10.0,100.0,10)
# tshours = [10.0]
# # #P_turb_des = [20.0] # for lf
# # eta_pump = [0.85] # for ptc
# R_all_lf = Dict()
# global msg = ""
# for (key, value) in cities_dict
#     if key in keys(R_all_ptc)
#         continue
#     else
#         R = Dict()  
#         for t in tshours # for mst
#             inputs = Dict()
#             # inputs["tshours"] = t # for mst and ptc
#             inputs["eta_pump"] = 0.85 # for lf
#             msg = "Began calculation for " * key * " and " * string(t) * "hrs. \n"
#             print(msg)
#             R[string(t)] = sum(run_ssc(model,value[1],value[2],inputs,outputs_dict[model]))
#         end
#         R_all_ptc[key] = collect(values(R))
#     end
# end