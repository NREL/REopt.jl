# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

const PMD = PowerModelsDistribution

function Microgrid_Model(Microgrid_Settings::Dict{String, Any}; JuMP_Model="", ldf_inputs_dictionary="")
    # The main function to run all parts of the microgrid model

    StartTime_EntireModel = now() # Record the start time for the computation
    TimeStamp = Dates.format(now(), "mm-dd-yyyy")*"_"*Dates.format(now(), "HH-MM")

    Microgrid_Inputs = REopt.MicrogridInputs(; REopt.dictkeys_tosymbols(Microgrid_Settings)...)
    cd(Microgrid_Inputs.folder_location)
    if Microgrid_Inputs.generate_CSV_of_outputs || Microgrid_Inputs.generate_results_plots
        CreateOutputsFolder(Microgrid_Inputs, TimeStamp)
    end
    PrepareElectricLoads(Microgrid_Inputs)
    REopt_dictionary = PrepareREoptInputs(Microgrid_Inputs)    
    m_outagesimulator = "empty"
    model = "empty"
    model_BAU = "empty"
    
    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
                
        RunDataChecks(Microgrid_Inputs, REopt_dictionary)
        
        PMD_number_of_timesteps = length(Microgrid_Inputs.PMD_time_steps)

        REopt_Results, PMD_Results, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, DataDictionaryForEachNode, LineInfo_PMD, REoptInputs_Combined, data_eng, data_math_mn, model, pm, line_upgrade_options_each_line, line_upgrade_results = build_run_and_process_results(Microgrid_Inputs, PMD_number_of_timesteps, TimeStamp; allow_upgrades = true)

        if Microgrid_Inputs.run_outage_simulator
            Outage_Results, single_model_outage_simulator, outage_simulator_time_milliseconds = run_outage_simulator(DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp, LineInfo_PMD)
        else
            Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
            single_model_outage_simulator = "N/A"
            outage_simulator_time_milliseconds = "N/A"
        end 

        if Microgrid_Inputs.run_BAU_case
            Microgrid_Settings_No_Techs = SetTechSizesToZero(Microgrid_Settings)
            Microgrid_Inputs_No_Techs = REopt.MicrogridInputs(; REopt.dictkeys_tosymbols(Microgrid_Settings_No_Techs)...)
            PrepareElectricLoads(Microgrid_Inputs_No_Techs)
            
            Outage_Results_No_Techs = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
            
            REopt_Results_BAU, PMD_Results_No_Techs, DataFrame_LineFlow_Summary_No_Techs, Dictionary_LineFlow_Power_Series_No_Techs, DataDictionaryForEachNode_No_Techs, LineInfo_PMD_No_Techs, REoptInputs_Combined_No_Techs, data_eng_No_Techs, data_math_mn_No_Techs, model_No_Techs, pm_No_Techs, line_upgrade_options_each_line_NoTechs, line_upgrade_results_NoTechs = build_run_and_process_results(Microgrid_Inputs_No_Techs, PMD_number_of_timesteps, TimeStamp; allow_upgrades = false)
            ComputationTime_EntireModel = "N/A"
            model_BAU = pm_No_Techs.model
            system_results_BAU = REopt.Results_Compilation(model_BAU, REopt_Results_BAU, PMD_Results, Outage_Results_No_Techs, Microgrid_Inputs_No_Techs, DataFrame_LineFlow_Summary_No_Techs, Dictionary_LineFlow_Power_Series_No_Techs, TimeStamp, ComputationTime_EntireModel; system_results_BAU = "")
            
        else
            system_results_BAU = "none"
            REopt_Results_BAU = "none"
            model_BAU = "none"
        end

        ComputationTime_EntireModel = CalculateComputationTime(StartTime_EntireModel)
        
        system_results = REopt.Results_Compilation(model, REopt_Results, PMD_Results, Outage_Results, Microgrid_Inputs, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; bau_model = model_BAU, system_results_BAU = system_results_BAU, outage_simulator_time = outage_simulator_time_milliseconds)

        # Compile output data into a dictionary to return from the dictionary
        CompiledResults = Dict([("System_Results", system_results),
                                ("System_Results_BAU", system_results_BAU),
                                ("DataDictionaryForEachNode", DataDictionaryForEachNode),
                                ("Microgrid_Inputs", Microgrid_Inputs), 
                                ("Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                                ("PMD_results", PMD_Results),
                                ("PMD_data_eng", data_eng),
                                ("REopt_results", REopt_Results),
                                ("REopt_results_BAU", REopt_Results_BAU),
                                ("Outage_Results", Outage_Results),
                                ("DataFrame_LineFlow_Summary", DataFrame_LineFlow_Summary),
                                ("ComputationTime_EntireModel", ComputationTime_EntireModel),
                                ("Line_Info_PMD", LineInfo_PMD),
                                #("pm", pm), # This can be a very large variable and it can be slow to load
                                ("line_upgrade_options", line_upgrade_options_each_line),
                                ("line_upgrade_results", line_upgrade_results),
                                ("single_outage_simulator_model", single_model_outage_simulator)
                                #("transformer_upgrade_options", transformer_upgrade_options_output),
                                #("transformer_upgrade_results", transformer_upgrade_results_output)
                                #("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series) 
                                ])
    end

    if Microgrid_Inputs.generate_results_plots == true 
        Create_Voltage_Plot(CompiledResults, TimeStamp, Microgrid_Inputs.voltage_plot_time_step)
        PlotPowerFlows(CompiledResults, TimeStamp, Microgrid_Inputs.time_steps_for_results_dashboard)
        Aggregated_PowerFlows_Plot(CompiledResults, TimeStamp, Microgrid_Inputs, REoptInputs_Combined, model)
        if Microgrid_Inputs.bus_coordinates != ""
            CreateResultsMap(CompiledResults, Microgrid_Inputs, TimeStamp)
        end
    end

    return CompiledResults, model, model_BAU, m_outagesimulator;  
end


function PrepareElectricLoads(Microgrid_Inputs)
    # Prepare the electric loads
    REopt_inputs_all_nodes = Microgrid_Inputs.REopt_inputs_list

    # Prepare loads for using with the outage simulator, if the fraction method is used for determining the critical load
    if  Microgrid_Inputs.critical_load_method == "Fraction"
        load_profiles_for_outage_sim_if_using_the_fraction_method = Dict([])
        for REopt_inputs in REopt_inputs_all_nodes
            load_profiles_for_outage_sim_if_using_the_fraction_method[REopt_inputs["Site"]["node"]] = deepcopy( REopt_inputs["ElectricLoad"]["loads_kw"] )
        end
        Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method = load_profiles_for_outage_sim_if_using_the_fraction_method
    else
        Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method = ""
    end
    
    # If outages are defined in the optimization, set the loads to the critical loads during the outages
    if Microgrid_Inputs.model_outages_with_outages_vector
        if Microgrid_Inputs.outages_vector != []

            for i in 1:length(Microgrid_Inputs.REopt_inputs_list)
                if sum(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"]) > 0 # only apply the critical load fraction if there is a load on the node

                    node = Microgrid_Inputs.REopt_inputs_list[i]["Site"]["node"]
                    
                    load_segment_initial = deepcopy(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"])
                    for outage_timestep in Microgrid_Inputs.outages_vector
                        if Microgrid_Inputs.critical_load_method == "Fraction"
                            Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"][outage_timestep] = Microgrid_Inputs.critical_load_fraction[string(node)] * load_segment_initial[outage_timestep]
                        elseif Microgrid_Inputs.critical_load_method == "TimeSeries"
                            Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"][outage_timestep] = Microgrid_Inputs.critical_load_timeseries[string(node)][outage_timestep]
                        end
                    end
                end
            end
        end
    elseif Microgrid_Inputs.single_outage_end_time_step - Microgrid_Inputs.single_outage_start_time_step > 0
        
        OutageStart = Microgrid_Inputs.single_outage_start_time_step
        OutageEnd = Microgrid_Inputs.single_outage_end_time_step

        for i in 1:length(Microgrid_Inputs.REopt_inputs_list)
            
            node = Microgrid_Inputs.REopt_inputs_list[i]["Site"]["node"]

            if Microgrid_Inputs.critical_load_method == "Fraction"
                if sum(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"]) > 0 # only apply the critical load fraction if there is a load on the node
                    load_segment_initial = deepcopy(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = Microgrid_Inputs.critical_load_fraction[string(node)] * load_segment_initial[OutageStart:OutageEnd]                    
                    delete!(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"],"loads_kw")
                    Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end 
            elseif Microgrid_Inputs.critical_load_method == "TimeSeries"
                if sum(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"]) > 0 
                    load_segment_initial = deepcopy(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = Microgrid_Inputs.critical_load_timeseries[string(node)][OutageStart:OutageEnd]                    
                    delete!(Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"],"loads_kw")
                    Microgrid_Inputs.REopt_inputs_list[i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end
            end
        end
    end     
end


function build_run_and_process_results(Microgrid_Inputs, PMD_number_of_timesteps, timestamp; allow_upgrades=false)
    # Function to build the model, run the model, and process results

    # Empty these variables from any previous contents
    pm = nothing
    data_math_mn = nothing
    data_eng = nothing

    pm, data_math_mn, data_eng = Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs, PMD_number_of_timesteps)
        
    LineInfo_PMD, data_math_mn, REoptInputs_Combined, pm = Build_REopt_and_Link_To_PMD(pm, Microgrid_Inputs, data_math_mn)
    
    line_upgrade_options_each_line = "N/A"
    if allow_upgrades == true
        if Microgrid_Inputs.model_line_upgrades == true
            pm, line_upgrade_options_each_line = model_line_upgrades(pm, Microgrid_Inputs, LineInfo_PMD, data_eng)          
        end

        if Microgrid_Inputs.model_transformer_upgrades == true
            #pm = model_transformer_upgrades(pm, Microgrid_Inputs)
        end

    end

    add_objective(pm, Microgrid_Inputs, REoptInputs_Combined)

    results, TerminationStatus = Run_REopt_PMD_Model(pm, Microgrid_Inputs)
    
    REopt_Results, PMD_Results, DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, DataFrame_LineFlow_Summary, line_upgrade_results = Results_Processing_REopt_PMD_Model(pm.model, results, data_math_mn, REoptInputs_Combined, Microgrid_Inputs, timestamp; allow_upgrades=allow_upgrades, line_upgrade_options_each_line = line_upgrade_options_each_line)
    
    return REopt_Results, PMD_Results, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, DataDictionaryForEachNode, LineInfo_PMD, REoptInputs_Combined, data_eng, data_math_mn, pm.model, pm, line_upgrade_options_each_line, line_upgrade_results
end

function create_list_of_upgradable_lines(Microgrid_Inputs)
    # Create a list lines that are upgradable

    lines_for_upgrades_temp = []
    for i in keys(Microgrid_Inputs.line_upgrade_options)
        push!(lines_for_upgrades_temp, Microgrid_Inputs.line_upgrade_options[i]["locations"]) 
    end
    lines_for_upgrades = unique!(lines_for_upgrades_temp)[1]

    return lines_for_upgrades
end

function model_line_upgrades(pm, Microgrid_Inputs, LineInfo, data_eng)
    # Function for modeling line upgrades

    lines_for_upgrades = create_list_of_upgradable_lines(Microgrid_Inputs)

    print("\n The lines for upgrades are: $(lines_for_upgrades) ")

    # Define variables for the line cost and line max amps
    @variable(pm.model, line_cost[lines_for_upgrades] >= 0 )
    @variable(pm.model, line_max_amps[lines_for_upgrades] >= 0)
    
    # Generate a dictionary for the options, organized so that the keys are the lines and the values are options for each line
    line_upgrade_options_each_line = Dict([])
    for line in lines_for_upgrades

        for i in keys(Microgrid_Inputs.line_upgrade_options), j in Microgrid_Inputs.line_upgrade_options[i]["locations"]
            if line == j

                if line ∉ keys(line_upgrade_options_each_line) # create a new entry for that line if it is not in the line_upgrade_options_each_line dictionary

                    line_upgrade_options_each_line[line] = Dict([("max_amperage", [Microgrid_Inputs.line_upgrade_options[i]["max_amps"]]),
                                                                 ("cost_per_length", [Microgrid_Inputs.line_upgrade_options[i]["cost_per_meter"]]),
                                                                 ("voltage_kv", Microgrid_Inputs.line_upgrade_options[i]["voltage_kv"]) # all upgrade options for a given line should have the same voltage
                                                                 #("rvalues", [Microgrid_Inputs.line_upgrade_options[i]["rvalues"]]),
                                                                 #("xvalues", [Microgrid_Inputs.line_upgrade_options[i]["xvalues"]])
                                                                            ])            
                else
                    push!(line_upgrade_options_each_line[line]["max_amperage"], Microgrid_Inputs.line_upgrade_options[i]["max_amps"])
                    push!(line_upgrade_options_each_line[line]["cost_per_length"], Microgrid_Inputs.line_upgrade_options[i]["cost_per_meter"])
                    #push!(line_upgrade_options_each_line[line_name]["rvalues"], Microgrid_Inputs.line_upgrade_options[i]["rvalues"])
                    #push!(line_upgrade_options_each_line[line_name]["xvalues"], Microgrid_Inputs.line_upgrade_options[i]["xvalues"])
                end
            end
        end

        number_of_entries = length(line_upgrade_options_each_line[line]["max_amperage"])
        dv = "Bin"*line
        pm.model[Symbol(dv)] = @variable(pm.model, [1:number_of_entries], base_name=dv, Bin)
        line_length = data_eng["line"][line]["length"] 

        @constraint(pm.model, pm.model[:line_max_amps][line] == sum(pm.model[Symbol(dv)][i]*line_upgrade_options_each_line[line]["max_amperage"][i] for i in 1:number_of_entries))
        @constraint(pm.model, pm.model[:line_cost][line] == line_length * sum(pm.model[Symbol(dv)][i]*line_upgrade_options_each_line[line]["cost_per_length"][i] for i in 1:number_of_entries))
        @constraint(pm.model, sum(pm.model[Symbol(dv)][i] for i in 1:number_of_entries) == 1)

        # Constraint for limiting the power flow through line xxxx to the line_max_amps variable constrained
        i = LineInfo[line]["index"]
        
        # Based off of code in line 470 of PMD's src>core>constraint_template
        timestep = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
        branch = ref(pm, timestep, :branch, i)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_connections = branch["f_connections"]
        t_connections = branch["t_connections"]
        f_idx = (i, f_bus, t_bus)
        t_idx = (i, t_bus, f_bus)
        print("\n The f_idx for line $(line) is $(f_idx)")
        print("\n The t_idx for line $(line) is $(t_idx)")

        for timestep in Microgrid_Inputs.PMD_time_steps
            PMD_time_step = findall(x -> x==timestep, Microgrid_Inputs.PMD_time_steps)[1] #use the [1] to convert the 1-element vector into an integer
            
            p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
            p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]
            
            @constraint(pm.model, p_fr[1] <= pm.model[:line_max_amps][line] * line_upgrade_options_each_line[line]["voltage_kv"])
            @constraint(pm.model, p_fr[1] >= -pm.model[:line_max_amps][line] * line_upgrade_options_each_line[line]["voltage_kv"])

            @constraint(pm.model, p_to[1] <= pm.model[:line_max_amps][line] * line_upgrade_options_each_line[line]["voltage_kv"]) 
            @constraint(pm.model, p_to[1] >= -pm.model[:line_max_amps][line] * line_upgrade_options_each_line[line]["voltage_kv"]) 
            
        end
    end
    
    return pm, line_upgrade_options_each_line
end


function model_transformer_upgrades(pm, Microgrid_Inputs)


    return pm
end

function PrepareREoptInputs(Microgrid_Inputs)  
    # Generate the scenarios, REoptInputs, and list of REoptInputs
    scenarios = Dict([])
    for i in 1:length(Microgrid_Inputs.REopt_inputs_list)
        scenarios[i] = Scenario(Microgrid_Inputs.REopt_inputs_list[i])
    end

    REoptInputs_dictionary = Dict([])
    for i in 1:length(Microgrid_Inputs.REopt_inputs_list)
        REoptInputs_dictionary[i] = REoptInputs(scenarios[i])
    end

    REopt_dictionary = [REoptInputs_dictionary[1]]
    for i in 2:length(Microgrid_Inputs.REopt_inputs_list)
        push!(REopt_dictionary, REoptInputs_dictionary[i])
    end

    return REopt_dictionary
end

function SetTechSizesToZero(Microgrid_Settings)
    
    Microgrid_Settings_No_Techs = deepcopy(Microgrid_Settings)

    for i in 1:length(Microgrid_Settings_No_Techs["REopt_inputs_list"])
        if ("PV" in keys(Microgrid_Settings_No_Techs["REopt_inputs_list"][i])) && (string(Microgrid_Settings_No_Techs["REopt_inputs_list"][i]["Site"]["node"]) != Microgrid_Settings["facility_meter_node"])
            delete!(Microgrid_Settings_No_Techs["REopt_inputs_list"][i], "PV")
        end
        if "ElectricStorage" in keys(Microgrid_Settings_No_Techs["REopt_inputs_list"][i])
            delete!(Microgrid_Settings_No_Techs["REopt_inputs_list"][i], "ElectricStorage")
        end
        if "Generator" in keys(Microgrid_Settings_No_Techs["REopt_inputs_list"][i])
            delete!(Microgrid_Settings_No_Techs["REopt_inputs_list"][i], "Generator")
        end
    end
    
    Microgrid_Settings_No_Techs["single_outage_start_time_step"] = 0
    Microgrid_Settings_No_Techs["single_outage_end_time_step"] = 0
    Microgrid_Settings_No_Techs["outages_vector"] = []
    Microgrid_Settings_No_Techs["run_outage_simulator"] = false
    Microgrid_Settings_No_Techs["display_results"] = false
    Microgrid_Settings_No_Techs["generate_results_plots"] = false
    Microgrid_Settings_No_Techs["generate_CSV_of_outputs"] = false
    Microgrid_Settings_No_Techs["model_line_upgrades"] = false
    Microgrid_Settings_No_Techs["model_transformer_upgrades"] = false

    return Microgrid_Settings_No_Techs
end


function ApplyDataEngSettings(data_eng, Microgrid_Inputs)
    # Apply several miscellaneous settings to the data_eng dictionary

    data_eng["settings"]["sbase_default"] = 1.0*1E3/data_eng["settings"]["power_scale_factor"] # Set the power base (sbase) equal to 1 kW:
    data_eng["voltage_source"]["source"]["bus"] = "sourcebus"
    data_eng["settings"]["name"] = "OptimizationModel" 
    
    PMD.add_bus_absolute_vbounds!(
        data_eng,
        phase_lb_pu = Microgrid_Inputs.bus_phase_voltage_lower_bound_per_unit,
        phase_ub_pu = Microgrid_Inputs.bus_phase_voltage_upper_bound_per_unit, 
        neutral_ub_pu = Microgrid_Inputs.bus_neutral_voltage_upper_bound_per_unit
    )

end


function ApplyLoadProfileToPMDModel(data_eng, PMD_number_of_timesteps, REopt_nodes)
    # Apply a timeseries load profile to the PMD model
    
    data_eng["time_series"] = Dict{String,Any}()
    data_eng["time_series"]["normalized_load_profile"] = Dict{String,Any}("replace" => false,
                                                                          "time" => 1:PMD_number_of_timesteps,
                                                                          "values" => zeros(PMD_number_of_timesteps)
                                                                          )

    for i in REopt_nodes
            data_eng["load"]["load$(i)"]["time_series"] = Dict(
                    "pd_nom"=>"normalized_load_profile",
                    "qd_nom"=> "normalized_load_profile"
            )
    end
end


function CreatePMDGenerators(data_eng, REopt_nodes)
    # Add a generic PMD generator for each REopt node to the model, in order to be able to connect the REopt and PMD models
    
    # TODO: This needs to be adjusted for three phase loads that are on phases other than just phase 1 (mainly in the "connections" field and/or "configuration" field)
    data_eng["generator"] = Dict{String, Any}()
    for e in REopt_nodes
        data_eng["generator"]["REopt_gen_$e"] = Dict{String,Any}(
                    "status" => PMD.ENABLED,
                    "bus" => data_eng["load"]["load$(e)"]["bus"],   
                    "connections" => [data_eng["load"]["load$(e)"]["connections"][1], 4], # Note: From PMD tutorial: "create a generator with the same connection setting."
                    "configuration" => WYE,
        )
    end
end


function Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs, PMD_number_of_timesteps; RunningOutageSimulator = false)
    
    print("\n Parsing the network input file \n")
    data_eng = PowerModelsDistribution.parse_file(Microgrid_Inputs.folder_location.*"/"*Microgrid_Inputs.PMD_network_input) # Load in the data from the OpenDSS inputs file; data is stored to the data_eng variable
        
    REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs) # Generate a list of the REopt nodes
        
    ApplyDataEngSettings(data_eng, Microgrid_Inputs)
    
    ApplyLoadProfileToPMDModel(data_eng, PMD_number_of_timesteps, REopt_nodes)
    
    CreatePMDGenerators(data_eng, REopt_nodes)

    data_math_mn = transform_data_model(data_eng, multinetwork=true) # Transforming the engineering model to a mathematical model in PMD 
    
    # Initialize voltage variable values. 
    Start_vrvi = now()
    add_start_vrvi!(data_math_mn)
    End_vrvi = now()
    
    # Measure and report the time for initializing the voltage variable values
    PMD_vrvi_time = End_vrvi - Start_vrvi
    PMD_vrvi_time_minutes = round(PMD_vrvi_time/Millisecond(60000), digits=2)
    print("\n The PMD_vrvi_time was: $(PMD_vrvi_time_minutes) minutes \n")
    
    print("\n Instantiating the PMD model (this may take a few minutes for large models)\n")
    Start_instantiate = now()
    pm = instantiate_mc_model(data_math_mn, LPUBFDiagPowerModel, build_mn_mc_opf) # Note: instantiate_mc_model automatically converts the "engineering" model into a "mathematical" model
    End_instantiate = now()
    
    PMD_instantiate_time = End_instantiate - Start_instantiate
    PMD_instantiate_time_minutes = round(PMD_instantiate_time/Millisecond(60000), digits=2)
    print("\n The PMD_instantiate_time was: $(PMD_instantiate_time_minutes) minutes \n")

    return pm, data_math_mn, data_eng;
end


function CreateREoptTotalExportVariables(m, REoptInputs_Combined)
    # Create Total Export variables for each REopt node, except for the facility meter node

    for p in REoptInputs_Combined
        _n = string("_", p.s.site.node)
        if string(p.s.site.node) != p.s.settings.facilitymeter_node
            m[Symbol("TotalExport"*_n)] = @expression(m, [ts in p.time_steps],
                sum(
                    m[Symbol("dvProductionToGrid"*_n)][t,u,ts] 
                    for t in p.techs.elec, u in p.export_bins_by_tech[t]
                )
                + sum(m[Symbol("dvStorageToGrid"*_n)][b,ts] for b in p.s.storage.types.all ) # This line includes battery export in the total export
            )
        else
            print("\n Not creating a total export variable for node $(p.s.site.node) because this node is the facility meter node.")
        end
    end

end

    
function LinkREoptAndPMD(pm, m, data_math_mn, Microgrid_Inputs, REopt_nodes)
    # Link the PMD and REopt variables through constraints

    gen_name2ind = Dict(gen["name"] => gen["index"] for (_,gen) in data_math_mn["nw"]["1"]["gen"]);
    
    REopt_gen_ind_e = [gen_name2ind["REopt_gen_$e"] for e in REopt_nodes];
    
    PMDTimeSteps_InREoptTimes = Microgrid_Inputs.PMD_time_steps
    PMDTimeSteps_Indeces = collect(1:length(PMDTimeSteps_InREoptTimes))
     
    PMD_Pg_ek = [PMD.var(pm, k, :pg, e).data[1] for e in REopt_gen_ind_e, k in PMDTimeSteps_Indeces] 
    PMD_Qg_ek = [PMD.var(pm, k, :qg, e).data[1] for e in REopt_gen_ind_e, k in PMDTimeSteps_Indeces]
    
    buses = REopt_nodes
    
    for e in REopt_gen_ind_e  #Note: the REopt_gen_ind_e does not contain the facility meter
        JuMP.@constraint(m, [k in PMDTimeSteps_Indeces],  
                            PMD_Pg_ek[e,k] == m[Symbol("TotalExport_"*string(buses[e]))][PMDTimeSteps_InREoptTimes[k]]  - m[Symbol("dvGridPurchase_"*string(buses[e]))][PMDTimeSteps_InREoptTimes[k]]   # negative power "generation" is a load
        )
        # TODO: add reactive power to the REopt nodes
        JuMP.@constraint(m, [k in PMDTimeSteps_Indeces],
                            PMD_Qg_ek[e,k] == 0.0 #m[Symbol("TotalExport_"*string(buses[e]))][PMDTimeSteps_InREoptTimes[k]] - m[Symbol("dvGridPurchase_"*string(buses[e]))][PMDTimeSteps_InREoptTimes[k]] 
        )
    end

    return REopt_gen_ind_e

end


function Build_REopt_and_Link_To_PMD(pm, Microgrid_Inputs, data_math_mn; OutageSimulator=false, OutageLength_Timesteps=0)
    
    m = pm.model   
    REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs)
    REoptInputs_Combined = PrepareREoptInputs(Microgrid_Inputs)  
    
    print("\n Building the REopt model\n")
    REopt.build_reopt!(m, REoptInputs_Combined) # Pass the PMD JuMP model (with the PowerModelsDistribution variables and constraints) as the JuMP model that REopt should build onto
    
    CreateREoptTotalExportVariables(m, REoptInputs_Combined)
    REopt_gen_ind_e = LinkREoptAndPMD(pm, m, data_math_mn, Microgrid_Inputs, REopt_nodes)
    LineInfo = CreateLineInfoDictionary(pm)
    REoptTimeSteps = collect(1:(Microgrid_Inputs.time_steps_per_hour * 8760))
    ApplyGridImportAndExportConstraints(Microgrid_Inputs, REoptInputs_Combined, pm, m, REoptTimeSteps, LineInfo, OutageSimulator, OutageLength_Timesteps)
    LinkFacilityMeterNodeToSubstationPower(m, pm, Microgrid_Inputs, REoptInputs_Combined, LineInfo, REopt_gen_ind_e, REoptTimeSteps, REopt_nodes)
    Node_Import_Export_Constraints_For_Non_PMD_Timesteps(m, Microgrid_Inputs, LineInfo)

    if Microgrid_Inputs.generators_only_run_during_grid_outage == true
        LimitGeneratorOperatingTimes(m, Microgrid_Inputs, REoptInputs_Combined)
    end

    return LineInfo, data_math_mn, REoptInputs_Combined, pm;
end


function add_objective(pm, Microgrid_Inputs, REoptInputs_Combined)

    @expression(pm.model, Costs, sum(pm.model[Symbol(string("Costs_", p.s.site.node))] for p in REoptInputs_Combined) )
    
    if Microgrid_Inputs.model_line_upgrades
        @info "Including the line upgrade costs in the Costs expression"
        lines_for_upgrades = create_list_of_upgradable_lines(Microgrid_Inputs)

        @variable(pm.model, total_line_upgrade_cost >= 0)
        @constraint(pm.model, pm.model[:total_line_upgrade_cost] == sum(pm.model[:line_cost][line] for line in lines_for_upgrades))

        add_to_expression!(Costs, pm.model[:total_line_upgrade_cost])
    end

    @objective(pm.model, Min, pm.model[:Costs]) # Define the optimization objective

end


function Node_Import_Export_Constraints_For_Non_PMD_Timesteps(m, Microgrid_Inputs, LineInfo)
    # Apply basic constraints to limit export from and import to nodes

    # TODO: finish this function

    # For each node:

        # Power import and export must be less than the sum of the line capacities connected to that node

end


function ApplyGridImportAndExportConstraints(Microgrid_Inputs, REoptInputs_Combined, pm, m, REoptTimeSteps, LineInfo, OutageSimulator, OutageLength_Timesteps)
    # Apply a variety of grid import and/or export constraints:
    
    # Restrict power flow from the substation if the microgrid type is offgrid
    if Microgrid_Inputs.microgrid_type == "Offgrid" 
        RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, REoptTimeSteps, LineInfo; Off_Grid=true)
    end
    
    # Define limits on grid import and export
    if Microgrid_Inputs.allow_export_beyond_substation == false # Prevent power from being exported to the grid beyond the facility meter:
        print("\n Prohibiting power export at the substation")
        #RestrictLinePowerFlow(Microgrid_Inputs, pm, m, Microgrid_Inputs.substation_line, REoptTimeSteps, LineInfo; Prevent_Export=true) # This constraint is handled by other constraints below
    elseif Microgrid_Inputs.substation_export_limit != ""
        print("\n Applying a limit to the power export at the substation")
        RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, REoptTimeSteps, LineInfo; Substation_Export_Limit = Microgrid_Inputs.substation_export_limit)
    end 
    
    if Microgrid_Inputs.substation_import_limit != ""
        print("\n Applying a limit to the power import from the substation")
        RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, REoptTimeSteps, LineInfo; Substation_Import_Limit = Microgrid_Inputs.substation_import_limit)
    end 
    
    # Apply a grid outage to the model
    if Microgrid_Inputs.model_outages_with_outages_vector
        if Microgrid_Inputs.outages_vector != []
            print("\n Applying a grid outages on the following timesteps: ")
            print(Microgrid_Inputs.model_outages_with_outages_vector)
            RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, Microgrid_Inputs.outages_vector, LineInfo; Grid_Outage=true, OutageSimulator = OutageSimulator, OutageLength_Timesteps = OutageLength_Timesteps)
        end    
    elseif Microgrid_Inputs.single_outage_end_time_step - Microgrid_Inputs.single_outage_start_time_step > 0
        print("\n Applying a grid outage from time step $(Microgrid_Inputs.single_outage_start_time_step) to $(Microgrid_Inputs.single_outage_end_time_step) ")
        RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, collect(Microgrid_Inputs.single_outage_start_time_step:Microgrid_Inputs.single_outage_end_time_step), LineInfo; Grid_Outage=true, OutageSimulator = OutageSimulator, OutageLength_Timesteps = OutageLength_Timesteps)
    end
    
    # Open switches if defined by the user
        # Note: the switch capability in PMD is not used currently in this model, but the switch openings are modeling with these constraints
    if (Microgrid_Inputs.switch_open_timesteps != "") && (Microgrid_Inputs.model_switches == true)
        print("\n Switches modeled:")
        for i in keys(Microgrid_Inputs.switch_open_timesteps)
            #print("\n   Opening the switch on line $(i) from timesteps $(minimum(Microgrid_Inputs.switch_open_timesteps[i])) to $(maximum(Microgrid_Inputs.switch_open_timesteps[i])) \n")
            RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, i, Microgrid_Inputs.switch_open_timesteps[i], LineInfo; Switches_Open=true)
        end
    end
    
end


function LinkFacilityMeterNodeToSubstationPower(m, pm, Microgrid_Inputs, REoptInputs_Combined, LineInfo, REopt_gen_ind_e, REoptTimeSteps, REopt_nodes)
    # Link export through the substation to the utility tariff on the facility meter node
    
    PMDTimeSteps_InREoptTimes = Microgrid_Inputs.PMD_time_steps
    buses = REopt_nodes

    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            #@info "The export bins for the facility meter node are: $(p.export_bins_by_tech["PV"])"
            
            i = LineInfo[Microgrid_Inputs.substation_line]["index"]
            # Based off of code in line 470 of PMD's src>core>constraint_template
                timestep = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
                branch = ref(pm, timestep, :branch, i)
                f_bus = branch["f_bus"]
                t_bus = branch["t_bus"]
                f_connections = branch["f_connections"]
                t_connections = branch["t_connections"]
                f_idx = (i, f_bus, t_bus)
                t_idx = (i, t_bus, f_bus)
    
            @variable(m, binSubstationPositivePowerFlow[ts in REoptTimeSteps], Bin)
            @variable(m, dvSubstationPowerFlow[ts in REoptTimeSteps])
                        
            for timestep in REoptTimeSteps
                # Previous constraints with indicator constraints
                #@constraint(m, m[:binSubstationPositivePowerFlow][timestep] => {m[:dvSubstationPowerFlow][timestep] >= 0 } )  # TODO: make this compatible with phase 2 and 3 of three phase (right now it's only consider 1-phase I think)
                #@constraint(m, !m[:binSubstationPositivePowerFlow][timestep] => {m[:dvSubstationPowerFlow][timestep] <= 0 } )
                   
                # New constraints without indicator constraints:
                @constraint(m, m[:dvSubstationPowerFlow][timestep] <= m[:binSubstationPositivePowerFlow][timestep] * 1000000 )
                @constraint(m, m[:dvSubstationPowerFlow][timestep] >=  (1 - m[:binSubstationPositivePowerFlow][timestep]) * -1000000 )

                if Microgrid_Inputs.allow_export_beyond_substation == true
                    # Set the power flowing through the line from the substation to be the grid purchase minus the dvProductionToGrid for node 15
                    #TODO: make this compatible with three phase power- I believe p_fr[1] only refers to the first phase: might be able to say:  p_fr .>= 0   with the period
                    
                    if timestep in PMDTimeSteps_InREoptTimes
                        
                        PMD_time_step = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer

                        p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
                        p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]
                
                        q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
                        q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]

                        @constraint(m, m[:dvSubstationPowerFlow][timestep] == p_fr[1])

                    else
                        # Instead of using the line flow from PMD, consider the total system inflow/outflow to be based on a lumped-element model, which sums all power inflows and outflows for each node
                        @constraint(m, m[:dvSubstationPowerFlow][timestep] ==
                            (-sum(m[Symbol("TotalExport_"*string(buses[e]))][timestep] for e in REopt_gen_ind_e) + 
                            sum(m[Symbol("dvGridPurchase_"*string(buses[e]))][timestep] for e in REopt_gen_ind_e)))
                    end

                    @constraint(m, m[:dvSubstationPowerFlow][timestep] == (sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - 
                                                                                sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]))) 
            
                    @constraint(m, sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) <= Microgrid_Inputs.substation_import_limit * m[:binSubstationPositivePowerFlow][timestep])
                    
                    @constraint(m, sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]) <= Microgrid_Inputs.substation_export_limit * (1 - m[:binSubstationPositivePowerFlow][timestep]))
                    
                    @constraint(m, sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) >= 0)
                    
                    @constraint(m, sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]) >= 0)
                                    
                else
                    @info "Not allowing export from the facility meter"
                    
                    @constraint(m, sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]) == 0)

                    if timestep in PMDTimeSteps_InREoptTimes
                        PMD_time_step = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer

                        p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
                        p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]
                
                        q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
                        q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]

                        @constraint(m, sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) == p_fr[1])
                        
                        @constraint(m, m[:dvSubstationPowerFlow][timestep] == p_fr[1]) 
                        @constraint(m, m[:dvSubstationPowerFlow][timestep] >= 0) 
                             
                    else
                        # Instead of using the line flow from PMD, consider the total system inflow/outflow to be based on a lumped-element model, which sums all power inflows and outflows for each node
                        @constraint(m,
                            (sum(m[Symbol("TotalExport_"*string(buses[e]))][timestep] for e in REopt_gen_ind_e)  - 
                            sum(m[Symbol("dvGridPurchase_"*string(buses[e]))][timestep] for e in REopt_gen_ind_e)) == 
                            (sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers)))
                    
                        @constraint(m, m[:dvSubstationPowerFlow][timestep] == (sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers))) 
                        @constraint(m, m[:dvSubstationPowerFlow][timestep] >= 0)
                        
                    end
                end
            end
        end
    end
end


function LimitGeneratorOperatingTimes(m, Microgrid_Inputs, REoptInputs_Combined)
    # Prevent the generators from generating power during times that aren't a grid outage

    if Microgrid_Inputs.model_outages_with_outages_vector == false
        NonOutageTimeSteps = vcat(collect(1:Microgrid_Inputs.single_outage_start_time_step), collect(Microgrid_Inputs.single_outage_end_time_step:(8760*Microgrid_Inputs.time_steps_per_hour)))
    elseif Microgrid_Inputs.model_outages_with_outages_vector == true
        NonOutageTimeSteps = []
        for i in 1:(8760*Microgrid_Inputs.time_steps_per_hour)
            if !(i in Microgrid_Inputs.outages_vector) 
                push!(NonOutageTimeSteps, i)
            end
        end
    end

    for p in REoptInputs_Combined
        _n = "_"*string(p.s.site.node)
        if "Generator" in p.techs.elec
            for ts in NonOutageTimeSteps
			    fix(m[Symbol("dvRatedProduction"*_n)]["Generator", ts], 0.0, force=true)
            end       
        end
    end

end


function CreateLineInfoDictionary(pm)
    # Creates a dictionary with the line names and corresponding indeces for the :p decision variable
    LineInfo = Dict([])
    NumberOfBranches = length(ref(pm,1,:branch))
    for i in 1:NumberOfBranches
        LineData = PMD.ref(pm, 1, :branch, i)
        LineInfo[LineData["name"]] = Dict(["index"=>LineData["index"], "t_bus"=>LineData["t_bus"], "f_bus"=>LineData["f_bus"]])
    end
    return LineInfo
end


function Run_REopt_PMD_Model(pm, Microgrid_Inputs)
    # Run the optimization
    # Note: the "optimize_model!" function is a wrapper from PMD and it includes some organization of the results
    
    m = pm.model

    set_optimizer(m, Microgrid_Inputs.optimizer) 
    
    if Microgrid_Inputs.optimizer == Xpress.Optimizer
        set_optimizer_attribute(m, "MIPRELSTOP", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(m, "OUTPUTLOG", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)
    elseif Microgrid_Inputs.optimizer == Gurobi.Optimizer
        set_optimizer_attribute(m, "MIPGap", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(m, "OutputFlag", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)  
        set_optimizer_attribute(m, "LogToConsole", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)
    elseif Microgrid_Inputs.optimizer == HiGHS.Optimizer
        set_optimizer_attribute(m, "mip_rel_gap", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(m, "output_flag", false)
        set_optimizer_attribute(m, "log_to_console", false)
    else
        @info "The solver's default tolerance and log settings are being used for the optimization"
    end
    
    print("\n The optimization is starting\n")
    results = PMD.optimize_model!(pm) #  Option other fields: relax_intregrality=true, optimizer=HiGHS.Optimizer) # The default in PMD for relax_integrality is false
    print("\n The optimization is complete\n")
    
    TerminationStatus = string(results["termination_status"])
    if TerminationStatus != "OPTIMAL"
        throw(@error("The termination status of the optimization was"*string(results["termination_status"])))
    end
        
    return results, TerminationStatus;
end


function RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, line, REoptTimeSteps, LineInfo; Grid_Outage=false, Off_Grid=false, Switches_Open=false, Prevent_Export=false, Substation_Export_Limit="", Substation_Import_Limit="", OutageSimulator = false, OutageLength_Timesteps = 0)
    # Function used for restricting power flow for grid outages, times when switches are opened, and substation import and export limits
    
    # Save the REopt Inputs for the site not to a variable
    FacilityMeterNode_REoptInputs = ""
    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            #print("\n The facility meter node REopt inputs is being recorded")
            FacilityMeterNode_REoptInputs = p        
        end
    end

    # Save to a variable the timesteps that the power models distribution model is applied to
    if OutageSimulator == false
        PMDTimeSteps_InREoptTimes = Microgrid_Inputs.PMD_time_steps
        PMDTimeSteps_Indeces = collect(1:length(PMDTimeSteps_InREoptTimes))
    elseif OutageSimulator == true
        PMDTimeSteps_InREoptTimes = collect(1:OutageLength_Timesteps)
        PMDTimeSteps_Indeces = collect(1:OutageLength_Timesteps)
    end

    i = LineInfo[line]["index"]
    # Based off of code in line 470 of PMD's src>core>constraint_template
        timestep = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
        branch = ref(pm, timestep, :branch, i)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_connections = branch["f_connections"]
        t_connections = branch["t_connections"]
        f_idx = (i, f_bus, t_bus)
        t_idx = (i, t_bus, f_bus)

    for timestep in REoptTimeSteps

        if timestep in PMDTimeSteps_InREoptTimes
        # Based off of code in line 274 of PMD's src>core>constraints
            PMD_time_step = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer
            #print("\n The PMD_time_step is: ")
            #print(PMD_time_step)
            p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
            p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]

            q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
            q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]
        end
        # Note: p_fr has three connections for three phase (I think). So the expression   p_fr .>=  0   applies to all of the connections, given that there is a period before the ">=" term
        if Prevent_Export == true
            # If the timesteps are part of the PMD model, then apply the constraints to the lines in PMD
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr[1] .>= 0) 
                JuMP.@constraint(m, q_fr[1] .>= 0)
            # But if the timesteps are not part of the PMD model, they use the REopt variables
            else
                @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*Microgrid_Inputs.facility_meter_node)]["PV", u, timestep] for u in FacilityMeterNode_REoptInputs.export_bins_by_tech["PV"]) == 0)
            end
        end

        if Substation_Export_Limit != ""
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr[1] .>= -Substation_Export_Limit) # TODO: change this to deal with multi-phase power correctly: likely need to sum p_to across each of the connections
                JuMP.@constraint(m, q_fr[1] .>= -Substation_Export_Limit) # TODO apply power factor to the export limit for Q
            else
                @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*Microgrid_Inputs.facility_meter_node)]["PV", u, timestep] for u in FacilityMeterNode_REoptInputs.export_bins_by_tech["PV"]) <= Substation_Export_Limit)
            end
        end

        if Substation_Import_Limit != ""
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr[1] .<= Substation_Import_Limit)
                JuMP.@constraint(m, q_fr[1] .<= Substation_Import_Limit) # TODO apply power factor to the import limit for Q
            else
                @constraint(m, sum(m[Symbol("dvGridPurchase_"*Microgrid_Inputs.facility_meter_node)][timestep, tier] for tier in 1:FacilityMeterNode_REoptInputs.s.electric_tariff.n_energy_tiers) <= Substation_Import_Limit)
            end
        end

        if Off_Grid == true || Grid_Outage == true || Switches_Open==true
            # Restrict all power flow
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr .== 0)  # The _fr and _to variables are just indicating power flow in either direction on the line. In PMD, there is a constraint that requires  p_to = -p_fr 
                JuMP.@constraint(m, p_to .== 0)  # TODO test removing the "fr" constraints here in order to reduce the # of constraints in the model
                JuMP.@constraint(m, q_fr .== 0)
                JuMP.@constraint(m, q_to .== 0)
            elseif Switches_Open==false
                @constraint(m, 
                        sum(m[Symbol("dvGridPurchase_"*Microgrid_Inputs.facility_meter_node)][timestep, tier] for tier in 1:FacilityMeterNode_REoptInputs.s.electric_tariff.n_energy_tiers) == 0)
                @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*Microgrid_Inputs.facility_meter_node)]["PV", u, timestep] for u in FacilityMeterNode_REoptInputs.export_bins_by_tech["PV"]) == 0)
            elseif Switches_Open==true
                @warn "The switches were defined as open during a time period when the PMD model is not applied"
            end
        end
    end
end


function GenerateREoptNodesList(Microgrid_Inputs)
    REopt_nodes = []
    for i in Microgrid_Inputs.REopt_inputs_list
        if string(i["Site"]["node"]) != Microgrid_Inputs.facility_meter_node
            push!(REopt_nodes, i["Site"]["node"])
        end
    end
    return REopt_nodes
end


# Function to check for errors in the data inputs for the model
function RunDataChecks(Microgrid_Inputs,  REopt_dictionary)

    ps = REopt_dictionary
    
    for p in ps
        node_temp = p.s.site.node

        if p.s.settings.facilitymeter_node != Microgrid_Inputs.facility_meter_node
            throw(@error("The facilitymeter_node input for each REopt node must equal the facility_meter_node defined in the microgrid settings, which is $(Microgrid_Inputs.facility_meter_node)"))
        end

        if p.s.settings.time_steps_per_hour != Microgrid_Inputs.time_steps_per_hour
            throw(@error("The time steps per hour for each REopt node must match the time steps per hour defined in the microgrid settings dictionary"))
        end
        
        if Microgrid_Inputs.critical_load_method == "Fraction"
            if string(p.s.site.node) ∉ keys(Microgrid_Inputs.critical_load_fraction)
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load fraction in the critical_load_fraction input dictionary"))
                end
            end
        end

        if Microgrid_Inputs.critical_load_method == "TimeSeries"
            if string(p.s.site.node) ∉ keys(Microgrid_Inputs.critical_load_timeseries)
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load timeseries profile in the critical_load_timeseries input dictionary"))
                end
            end
        end
        # TODO: add data check to ensure that if a critical load method is defined, then there must be either a critical load fraction or a critical load timeseries dictionary   
        
        if Int(length(p.s.electric_load.loads_kw)) != Int(8760 * Microgrid_Inputs.time_steps_per_hour)
            throw(@error("At REopt node $(node_temp), the length of the electric loads vector does not correlate with the time steps per hour defined in the Microgrid_Inputs dictionary"))
        end
    end
    
    if Microgrid_Inputs.microgrid_type ∉ ["CommunityDistrict", "BehindTheMeter", "OffGrid"]
        throw(@error("An invalid microgrid type was provided in the inputs"))
    end

    if Microgrid_Inputs.microgrid_type != "CommunityDistrict"
        @warn("For the community district microgrid type, the electricity tariff for the facility meter node should be 0")
    end

    if Microgrid_Inputs.generate_results_plots == true
        for i in Microgrid_Inputs.run_numbers_for_plotting_outage_simulator_results
            if i > Microgrid_Inputs.number_of_outages_to_simulate
                throw(@error("In the Microgrid_Inputs dictionary, all values for the run_numbers_for_plotting_outage_simulator_results must be less than the number_of_outages_to_simulate"))
            end
        end

        for i in Microgrid_Inputs.time_steps_for_results_dashboard
            if i ∉ Microgrid_Inputs.PMD_time_steps
                throw(@error("Please adjust the following model inputs: Every time step for the results dashboard (time_steps_for_results_dashboard) must be in the PMD time steps (PMD_time_steps)."))
            end
        end
    end

    if Microgrid_Inputs.critical_load_method == "Fraction"
        for x in values(Microgrid_Inputs.critical_load_fraction)
            if x >= 5.0
                throw(@error("The critical_load_fraction load fraction should be entered as a fraction, not a percent. The model currently limits the critical_load_fraction to 5.0 (or 500%) to reduce possibility of user error. "))
            end
        end
    end

    if Microgrid_Inputs.single_outage_start_time_step > Microgrid_Inputs.single_outage_end_time_step
        throw(@error("In the Microgrid_Inputs dictionary, the single outage start time must be a smaller value than the single outage stop time"))
    end

    if Microgrid_Inputs.single_outage_end_time_step > (8760 * Microgrid_Inputs.time_steps_per_hour)
        TotalNumberOfTimeSteps = Int(8760 * Microgrid_Inputs.time_steps_per_hour)
        throw(@error("In the Microgrid_Inputs dictionary, the defined outage stop time must be less than the total number of time steps, which is $(TotalNumberOfTimeSteps)"))
    end
end


