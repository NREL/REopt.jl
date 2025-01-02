# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

const PMD = PowerModelsDistribution

"""
`microgrid` is an optional input with the following keys and default values:
```julia
    folder_location::String="",
    bus_coordinates::String="",  # Location of the csv document with the bus coordinates
    PMD_network_input::String="",
    microgrid_type::String="BehindTheMeter",  # Options: "BehindTheMeter", "CommunityDistrict", or "Offgrid"
    nonlinear_solver::Bool=false,
    model_type::String="BasicLinear",  #Options: "BasicLinear", "PowerModelsDistribution",
    run_BAU_case::Bool=true,
    optimizer::Any, # Such as HiGHS.Optimizer
    optimizer_tolerance::Float64=0.001, # Only works for Xpress and Gurobi
    PMD_time_steps::Any=[1:24], # By default, apply the PMD model to the first 24 timesteps of the model
    REopt_inputs_list::Array=[],
    bus_phase_voltage_lower_bound_per_unit::Float64=0.95,
    bus_phase_voltage_upper_bound_per_unit::Float64=1.05,
    bus_neutral_voltage_upper_bound_per_unit::Float64=0.1, 
    facility_meter_node::String="",
    substation_node::String="",
    substation_line::String="",
    allow_export_beyond_substation::Bool=false,
    substation_export_limit::Real=0,
    substation_import_limit::Real=0,
    model_switches::Bool=false,
    model_line_upgrades::Bool=false,
    line_upgrade_options::Dict=Dict(), 
    model_transformer_upgrades::Bool=false,
    transformer_upgrade_options::Dict=Dict(),
    switch_open_timesteps::Dict=Dict(),
    single_outage_start_time_step::Real=0,
    single_outage_end_time_step::Real=0,
    run_outage_simulator::Bool=false,
    length_of_simulated_outages_time_steps::Array=[],
    critical_load_method::String="Fraction",
    critical_load_fraction::Real=0.0,
    critical_load_timeseries::Array=[],
    number_of_outages_to_simulate::Real=0,
    run_numbers_for_plotting_outage_simulator_results::Array=[], 
    time_steps_per_hour::Real=0,
    generator_fuel_gallon_available::Dict=Dict(),
    generators_only_run_during_grid_outage::Bool=false,
    generate_CSV_of_outputs::Bool=false,
    generate_results_plots::Bool=false,
    result_plots_start_time_step::Real=0,
    result_plots_end_time_step::Real=0,
    plot_voltage_drop::Bool=true,
    plot_voltage_drop_node_numbers::Array=[],
    plot_voltage_drop_voltage_time_step::Real=0,
    display_results::Bool=true
"""

mutable struct MicrogridInputs <: AbstractMicrogrid
    folder_location
    bus_coordinates
    PMD_network_input
    microgrid_type
    model_type
    run_BAU_case
    optimizer
    optimizer_tolerance
    PMD_time_steps
    nonlinear_solver
    REopt_inputs_list
    bus_phase_voltage_lower_bound_per_unit
    bus_phase_voltage_upper_bound_per_unit
    bus_neutral_voltage_upper_bound_per_unit
    facility_meter_node
    substation_node
    substation_line
    allow_export_beyond_substation
    substation_export_limit
    substation_import_limit
    model_switches
    model_line_upgrades
    line_upgrade_options 
    model_transformer_upgrades
    transformer_upgrade_options
    switch_open_timesteps
    single_outage_start_time_step
    single_outage_end_time_step
    run_outage_simulator
    length_of_simulated_outages_time_steps
    critical_load_method
    critical_load_fraction
    critical_load_timeseries
    number_of_outages_to_simulate
    run_numbers_for_plotting_outage_simulator_results
    time_steps_per_hour
    generator_fuel_gallon_available
    generators_only_run_during_grid_outage
    generate_CSV_of_outputs
    generate_results_plots
    result_plots_start_time_step
    result_plots_end_time_step
    plot_voltage_drop
    plot_voltage_drop_node_numbers
    plot_voltage_drop_voltage_time_step
    display_results
    load_profiles_for_outage_sim_if_using_the_fraction_method

    function MicrogridInputs(;
        folder_location::String="",
        bus_coordinates::String="",  
        PMD_network_input::String="",
        microgrid_type::String="BehindTheMeter", 
        model_type::String="PowerModelsDistribution",
        run_BAU_case::Bool=true, 
        optimizer::Any, 
        optimizer_tolerance::Float64=0.001,
        PMD_time_steps::Any=[1:24],
        nonlinear_solver::Bool=false,
        REopt_inputs_list::Array=[],
        bus_phase_voltage_lower_bound_per_unit::Float64=0.95,
        bus_phase_voltage_upper_bound_per_unit::Float64=1.05,
        bus_neutral_voltage_upper_bound_per_unit::Float64=0.1,
        facility_meter_node::String="",
        substation_node::String="",
        substation_line::String="",
        allow_export_beyond_substation::Bool=false,
        substation_export_limit::Real=0,
        substation_import_limit::Real=0,
        model_switches::Bool=false,
        model_line_upgrades::Bool=false,
        line_upgrade_options::Dict=Dict(), 
        model_transformer_upgrades::Bool=false,
        transformer_upgrade_options::Dict=Dict(),
        switch_open_timesteps::Dict=Dict(),
        single_outage_start_time_step::Real=0,
        single_outage_end_time_step::Real=0,
        run_outage_simulator::Bool=false,
        length_of_simulated_outages_time_steps::Array=[],
        critical_load_method::String="Fraction",
        critical_load_fraction::Dict=Dict(),
        critical_load_timeseries::Dict=Dict(),
        number_of_outages_to_simulate::Real=0,
        run_numbers_for_plotting_outage_simulator_results::Array=[], 
        time_steps_per_hour::Real=0,
        generator_fuel_gallon_available::Dict=Dict(),
        generators_only_run_during_grid_outage::Bool=false,
        generate_CSV_of_outputs::Bool=false,
        generate_results_plots::Bool=false,
        result_plots_start_time_step::Real=0,
        result_plots_end_time_step::Real=0,
        plot_voltage_drop::Bool=true,
        plot_voltage_drop_node_numbers::Array=[],
        plot_voltage_drop_voltage_time_step::Real=0,
        display_results::Bool=true,
        load_profiles_for_outage_sim_if_using_the_fraction_method::Array=[]
        )
    
    new(
        folder_location,
        bus_coordinates,
        PMD_network_input,
        microgrid_type,
        model_type,
        run_BAU_case,
        optimizer,
        optimizer_tolerance,
        PMD_time_steps,  
        nonlinear_solver,
        REopt_inputs_list,
        bus_phase_voltage_lower_bound_per_unit,
        bus_phase_voltage_upper_bound_per_unit,
        bus_neutral_voltage_upper_bound_per_unit,
        facility_meter_node,
        substation_node,
        substation_line,
        allow_export_beyond_substation,
        substation_export_limit,
        substation_import_limit,
        model_switches,
        model_line_upgrades,
        line_upgrade_options, 
        model_transformer_upgrades,
        transformer_upgrade_options,
        switch_open_timesteps,
        single_outage_start_time_step,
        single_outage_end_time_step,
        run_outage_simulator,
        length_of_simulated_outages_time_steps,
        critical_load_method,
        critical_load_fraction,
        critical_load_timeseries,
        number_of_outages_to_simulate,
        run_numbers_for_plotting_outage_simulator_results,
        time_steps_per_hour,
        generator_fuel_gallon_available,
        generators_only_run_during_grid_outage,
        generate_CSV_of_outputs,
        generate_results_plots,
        result_plots_start_time_step,
        result_plots_end_time_step,
        plot_voltage_drop,
        plot_voltage_drop_node_numbers,
        plot_voltage_drop_voltage_time_step,
        display_results,
        load_profiles_for_outage_sim_if_using_the_fraction_method
    )
   
    end
end


function Microgrid_Model(Microgrid_Settings::Dict{String, Any}; JuMP_Model="", ldf_inputs_dictionary="")
    # The main function to run all parts of the microgrid model

    StartTime_EntireModel = now() # Record the start time for the computation
    TimeStamp = Dates.format(now(), "mm-dd-yyyy")*"_"*Dates.format(now(), "HH-MM")

    Microgrid_Inputs = REopt.MicrogridInputs(; REopt.dictkeys_tosymbols(Microgrid_Settings)...)
    cd(Microgrid_Inputs.folder_location)
    CreateOutputsFolder(Microgrid_Inputs, TimeStamp)
    PrepareElectricLoads(Microgrid_Inputs)
    REopt_dictionary = PrepareREoptInputs(Microgrid_Inputs)    
    m_outagesimulator = "empty"
    model = "empty"
    model_BAU = "empty"
    
    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
                
        RunDataChecks(Microgrid_Inputs, REopt_dictionary)
        
        PMD_number_of_timesteps = length(Microgrid_Inputs.PMD_time_steps)

        REopt_Results, PMD_Results, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, DataDictionaryForEachNode, LineInfo_PMD, REoptInputs_Combined, data_eng, data_math_mn, model, pm = build_run_and_process_results(Microgrid_Inputs, PMD_number_of_timesteps)

        if Microgrid_Inputs.run_outage_simulator
            Outage_Results = run_outage_simulator(DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp, LineInfo_PMD, data_math_mn)
        else
            Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
        end 

        if Microgrid_Inputs.run_BAU_case
            Microgrid_Settings_No_Techs = SetTechSizesToZero(Microgrid_Settings)
            Microgrid_Inputs_No_Techs = REopt.MicrogridInputs(; REopt.dictkeys_tosymbols(Microgrid_Settings_No_Techs)...)
            PrepareElectricLoads(Microgrid_Inputs_No_Techs)
            
            Outage_Results_No_Techs = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
            
            REopt_Results_BAU, PMD_Results_No_Techs, DataFrame_LineFlow_Summary_No_Techs, Dictionary_LineFlow_Power_Series_No_Techs, DataDictionaryForEachNode_No_Techs, LineInfo_PMD_No_Techs, REoptInputs_Combined_No_Techs, data_eng_No_Techs, data_math_mn_No_Techs, model_No_Techs, pm_No_Techs = build_run_and_process_results(Microgrid_Inputs_No_Techs, PMD_number_of_timesteps)
            ComputationTime_EntireModel = "N/A"
            model_BAU = pm_No_Techs.model
            system_results_BAU = REopt.Results_Compilation(model_BAU, REopt_Results_BAU, Outage_Results_No_Techs, Microgrid_Inputs_No_Techs, DataFrame_LineFlow_Summary_No_Techs, Dictionary_LineFlow_Power_Series_No_Techs, TimeStamp, ComputationTime_EntireModel)
            
        else
            system_results_BAU = ""
            REopt_Results_BAU = "none"
            model_BAU = "none"
        end

        ComputationTime_EntireModel = CalculateComputationTime(StartTime_EntireModel)
        
        system_results = REopt.Results_Compilation(model, REopt_Results, Outage_Results, Microgrid_Inputs, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; system_results_BAU = system_results_BAU)

        # Compile output data into a dictionary to return from the dictionary
        CompiledResults = Dict([("System_Results", system_results),
                                ("System_Results_BAU", system_results_BAU),
                                ("DataDictionaryForEachNode", DataDictionaryForEachNode), 
                                ("Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                                ("PMD_results", PMD_Results),
                                ("PMD_data_eng", data_eng),
                                ("REopt_results", REopt_Results),
                                ("REopt_results_BAU", REopt_Results_BAU),
                                ("Outage_Results", Outage_Results),
                                ("DataFrame_LineFlow_Summary", DataFrame_LineFlow_Summary),
                                ("ComputationTime_EntireModel", ComputationTime_EntireModel),
                                ("Line_Info_PMD", LineInfo_PMD),
                                #("pm", pm) # This can be a very large variable and it can be slow to load
                                #("line_upgrade_options", line_upgrade_options_output),
                                #("transformer_upgrade_options", transformer_upgrade_options_output),
                                #("line_upgrade_results", line_upgrade_results_output),
                                #("transformer_upgrade_results", transformer_upgrade_results_output)
                                #("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series) 
                                ])

    elseif Microgrid_Inputs.model_type == "BasicLinear"
        # Note: this code running the BasicLinear model will likely be removed soon

        # Run function to check for errors in the model inputs
        RunDataChecks(Microgrid_Inputs, REopt_dictionary; ldf_inputs_dictionary = ldf_inputs_dictionary)
            
        # Run the optimization:
        DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results, DataFrame_LineFlow_Summary, LineNominalVoltages_Summary, BusNominalVoltages_Summary, model, lines_for_upgrades, line_upgrade_options, transformer_upgrade_options, line_upgrade_results, transformer_upgrade_results, line_upgrades_each_line, all_lines = Microgrid_REopt_Model_BasicLinear(JuMP_Model, Microgrid_Inputs, ldf_inputs_dictionary, REopt_dictionary, TimeStamp) # ps_B, TimeStamp) #
        
        # Run the outage simulator if "run_outage_simulator" is set to true
        if Microgrid_Inputs.run_outage_simulator == true
            OutageLengths = Microgrid_Inputs.length_of_simulated_outages_time_steps 
            NumberOfOutagesToTest = Microgrid_Inputs.number_of_outages_to_simulate

            line_max_amps = value.(model[:line_max_amps])
            if Microgrid_Inputs.model_line_upgrades == true && Microgrid_Inputs.nonlinear_solver == true
                lines_rmatrix = value.(model[:line_rmatrix])
                lines_xmatrix = value.(model[:line_xmatrix])
            else
                lines_rmatrix = []
                lines_xmatrix = []
            end
            transformer_max_kva = value.(model[:transformer_max_kva])
            Outage_Results = Dict([])
            for i in 1:length(OutageLengths)
                OutageLength = OutageLengths[i]
                OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived, m_outagesimulator = Microgrid_OutageSimulator(DataDictionaryForEachNode, 
                                                                                                                            REopt_dictionary, 
                                                                                                                            Microgrid_Inputs,  
                                                                                                                            TimeStamp;
                                                                                                                            line_max_amps=line_max_amps, 
                                                                                                                            lines_rmatrix=lines_rmatrix, 
                                                                                                                            lines_xmatrix=lines_xmatrix, 
                                                                                                                            lines_for_upgrades=lines_for_upgrades, 
                                                                                                                            line_upgrades_each_line=line_upgrades_each_line, 
                                                                                                                            all_lines=all_lines, 
                                                                                                                            transformer_max_kva=transformer_max_kva, 
                                                                                                                            BasicLinear_model=JuMP_Model, 
                                                                                                                            NumberOfOutagesToTest = NumberOfOutagesToTest, 
                                                                                                                            ldf_inputs_dictionary = ldf_inputs_dictionary, 
                                                                                                                            OutageLength_TimeSteps_Input = OutageLength)
                
                Outage_Results["$(OutageLength_TimeSteps)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, "NumberOfRuns" => RunNumber, "NumberOfOutagesSurvived" => SuccessfullySolved ])
            end 
        else
            Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
        end 

        EndTime_EntireModel = now()
        ComputationTime_EntireModel = EndTime_EntireModel - StartTime_EntireModel
        
        system_results = Results_Compilation(results, Outage_Results, Microgrid_Inputs, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; line_upgrade_results=dataframe_line_upgrade_summary, transformer_upgrade_results=dataframe_transformer_upgrade_summary)
    
        transformer_upgrade_options_output = transformer_upgrade_options
        transformer_upgrade_results_output = transformer_upgrade_results
        line_upgrade_options_output = line_upgrade_options
        line_upgrade_results_output = line_upgrade_results
    
       # Compile output data into a dictionary to return from the dictionary
        CompiledResults = Dict([("System_Results", system_results),
                                ("DataDictionaryForEachNode", DataDictionaryForEachNode), 
                                ("FromREopt_Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                                ("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series), 
                                ("ldf_inputs", ldf_inputs),
                                ("REopt_results", results),
                                ("Outage_Results", Outage_Results),
                                ("DataFrame_LineFlow_Summary", DataFrame_LineFlow_Summary),
                                ("LineNominalVoltages_Summary", LineNominalVoltages_Summary), 
                                ("BusNominalVoltages_Summary", BusNominalVoltages_Summary),
                                ("ComputationTime_EntireModel", ComputationTime_EntireModel),
                                ("line_upgrade_options", line_upgrade_options_output),
                                ("transformer_upgrade_options", transformer_upgrade_options_output),
                                ("line_upgrade_results", line_upgrade_results_output),
                                ("transformer_upgrade_results", transformer_upgrade_results_output)
                                ])
    end

    if Microgrid_Inputs.generate_results_plots == true 
        CreateResultsMap(CompiledResults, Microgrid_Inputs, TimeStamp)
        Aggregated_PowerFlows_Plot(CompiledResults, TimeStamp, Microgrid_Inputs, REoptInputs_Combined, model)
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
    if Microgrid_Inputs.single_outage_end_time_step - Microgrid_Inputs.single_outage_start_time_step > 0
        
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


function build_run_and_process_results(Microgrid_Inputs, PMD_number_of_timesteps)
    # Function to build the model, run the model, and process results

    pm, data_math_mn, data_eng = Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs, PMD_number_of_timesteps)
        
    LineInfo_PMD, data_math_mn, REoptInputs_Combined, pm = Build_REopt_and_Link_To_PMD(pm, Microgrid_Inputs, data_math_mn)
    
    results, TerminationStatus = Run_REopt_PMD_Model(pm, Microgrid_Inputs)
    
    REopt_Results, PMD_Results, DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, DataFrame_LineFlow_Summary = Results_Processing_REopt_PMD_Model(pm.model, results, data_math_mn, REoptInputs_Combined, Microgrid_Inputs)
    
    return REopt_Results, PMD_Results, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, DataDictionaryForEachNode, LineInfo_PMD, REoptInputs_Combined, data_eng, data_math_mn, pm.model, pm
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
    Microgrid_Settings_No_Techs["run_outage_simulator"] = false
    Microgrid_Settings_No_Techs["display_results"] = false
    Microgrid_Settings_No_Techs["generate_results_plots"] = false
    Microgrid_Settings_No_Techs["generate_CSV_of_outputs"] = false
    Microgrid_Settings_No_Techs["model_line_upgrades"] = false
    Microgrid_Settings_No_Techs["model_transformer_upgrades"] = false

    return Microgrid_Settings_No_Techs
end

function CreateOutputsFolder(Microgrid_Inputs, TimeStamp)
    # Create a folder for the outputs if saving results
    if Microgrid_Inputs.generate_CSV_of_outputs == true || Microgrid_Inputs.generate_results_plots == true
        @info "Creating a folder for the results"
        mkdir(Microgrid_Inputs.folder_location*"/results_"*TimeStamp)
    end
    if Microgrid_Inputs.generate_results_plots == true
        mkdir(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots") 
    end
end


function CalculateComputationTime(StartTime_EntireModel)
    # Function to calculate the elapsed time between a time (input into the function) and the current time
    EndTime_EntireModel = now()
    ComputationTime_EntireModel = EndTime_EntireModel - StartTime_EntireModel
    return ComputationTime_EntireModel
end


function run_outage_simulator(DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp, LineInfo_PMD, data_math_mn)
    
    Outage_Results = Dict([])

    # When line and transformer upgrades are implemented into the REopt-PMD model, define these inputs for the outage simulator
    line_max_amps = "N/A"
    lines_rmatrix= "N/A"
    lines_xmatrix= "N/A"
    lines_for_upgrades= "N/A"
    line_upgrades_each_line= "N/A"
    all_lines= "N/A"
    transformer_max_kva= "N/A"
    ldf_inputs_dictionary = "N/A"

    for i in 1:length(Microgrid_Inputs.length_of_simulated_outages_time_steps)
        OutageLength = Microgrid_Inputs.length_of_simulated_outages_time_steps[i]
        OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived = Microgrid_OutageSimulator(DataDictionaryForEachNode, 
                                                                                                                    REopt_dictionary, 
                                                                                                                    Microgrid_Inputs, 
                                                                                                                    TimeStamp;
                                                                                                                    LineInfo_PMD = LineInfo_PMD,
                                                                                                                    data_math_mn = data_math_mn, 
                                                                                                                    NumberOfOutagesToTest = Microgrid_Inputs.number_of_outages_to_simulate, 
                                                                                                                    OutageLength_TimeSteps_Input = OutageLength)
        Outage_Results["$(OutageLength_TimeSteps)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, "NumberOfRuns" => RunNumber, "NumberOfOutagesSurvived" => SuccessfullySolved ])
    end
    
    return Outage_Results
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

    #REoptInputsList = Microgrid_Inputs.REopt_inputs_list 
    
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
    
    if Microgrid_Inputs.generators_only_run_during_grid_outage == true
        LimitGeneratorOperatingTimes(m, Microgrid_Inputs, REoptInputs_Combined)
    end

    @expression(m, Costs, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in REoptInputs_Combined) )
    
    @objective(m, Min, m[:Costs]) # Define the optimization objective

    return LineInfo, data_math_mn, REoptInputs_Combined, pm;
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
    if Microgrid_Inputs.single_outage_end_time_step - Microgrid_Inputs.single_outage_start_time_step > 0
        print("\n Applying a grid outage from time step $(Microgrid_Inputs.single_outage_start_time_step) to $(Microgrid_Inputs.single_outage_end_time_step) ")
        RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, Microgrid_Inputs.substation_line, collect(Microgrid_Inputs.single_outage_start_time_step:Microgrid_Inputs.single_outage_end_time_step), LineInfo; Single_Outage=true, OutageSimulator = OutageSimulator, OutageLength_Timesteps = OutageLength_Timesteps)
    end
    
    # Open switches if defined by the user
        # Note: the switch capability in PMD is not used currently in this model, but the switch openings are modeling with these constraints
    if (Microgrid_Inputs.switch_open_timesteps != "") && (Microgrid_Inputs.model_switches == true)
        print("\n Switches modeled:")
        for i in keys(Microgrid_Inputs.switch_open_timesteps)
            #print("\n   Opening the switch on line $(i) from timesteps $(minimum(Microgrid_Inputs.switch_open_timesteps[i])) to $(maximum(Microgrid_Inputs.switch_open_timesteps[i])) \n")
            RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, "line"*i, Microgrid_Inputs.switch_open_timesteps[i], LineInfo; Switches_Open=true)
        end
    end
    
end


function LinkFacilityMeterNodeToSubstationPower(m, pm, Microgrid_Inputs, REoptInputs_Combined, LineInfo, REopt_gen_ind_e, REoptTimeSteps, REopt_nodes)
    # Link export through the substation to the utility tariff on the facility meter node
    
    PMDTimeSteps_InREoptTimes = Microgrid_Inputs.PMD_time_steps
    buses = REopt_nodes

    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            #@info "Setting facility-level grid purchase and export (if applicable) to the power flow on line "*string(Microgrid_Inputs.substation_line)*", using the variable: "*string(" dvGridPurchase_", p.s.settings.facilitymeter_node)
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
            
            #for t in REoptTimeSteps
            #    @constraint(m, dvSubstationPowerFlow[t] == (sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][t, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - 
            #                                                sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, t] for u in p.export_bins_by_tech["PV"]))) 
            #end
            
            for timestep in REoptTimeSteps

                @constraint(m, m[:binSubstationPositivePowerFlow][timestep] => {m[:dvSubstationPowerFlow][timestep] >= 0 } )  # TODO: make this compatible with phase 2 and 3 of three phase (right now it's only consider 1-phase I think)
                @constraint(m, !m[:binSubstationPositivePowerFlow][timestep] => {m[:dvSubstationPowerFlow][timestep] <= 0 } )
                   
                if Microgrid_Inputs.allow_export_beyond_substation == true
                    # Set the power flowing through the line from the substation to be the grid purchase minus the dvProductionToGrid for node 15
                    #TODO: make this compatible with three phase power- I believe p_fr[1] only refers to the first phase: might be able to say:  p_fr .>= 0   with the period
                    
                    if timestep in PMDTimeSteps_InREoptTimes
                        
                        PMD_time_step = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer

                        p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
                        p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]
                
                        q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
                        q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]

                        #@constraint(m, m[:binSubstationPositivePowerFlow][timestep] => {p_fr[1] >= 0 } )  # TODO: make this compatible with phase 2 and 3 of three phase (right now it's only consider 1-phase I think)
                        #@constraint(m, !m[:binSubstationPositivePowerFlow][timestep] => {p_fr[1] <= 0 } )
                    
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

    NonOutageTimeSteps = vcat(collect(1:Microgrid_Inputs.single_outage_start_time_step), collect(Microgrid_Inputs.single_outage_end_time_step:(8760*Microgrid_Inputs.time_steps_per_hour)))

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
    elseif Microgrid_Inputs.optimizer == Gurobi.Optimizer
        set_optimizer_attributes(m, "MIPGap", Microgrid_Inputs.optimizer_tolerance)
    else
        @info "The solver's default tolerance is being used for the optimization"
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


function RestrictLinePowerFlow(Microgrid_Inputs, REoptInputs_Combined, pm, m, line, REoptTimeSteps, LineInfo; Single_Outage=false, Off_Grid=false, Switches_Open=false, Prevent_Export=false, Substation_Export_Limit="", Substation_Import_Limit="", OutageSimulator = false, OutageLength_Timesteps = 0)
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
            # Set a substation export limit
           
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr[1] .>= -Substation_Export_Limit) # TODO: change this to deal with multi-phase power correctly: likely need to sum p_to across each of the connections
                JuMP.@constraint(m, q_fr[1] .>= -Substation_Export_Limit) # TODO apply power factor to the export limit for Q
            else
                @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*Microgrid_Inputs.facility_meter_node)]["PV", u, timestep] for u in FacilityMeterNode_REoptInputs.export_bins_by_tech["PV"]) <= Substation_Export_Limit)
            end
        end

        if Substation_Import_Limit != ""
            # Set a substation import limit
            #print("*********************** applying an import limit of $(Substation_Import_Limit)")
            if timestep in PMDTimeSteps_InREoptTimes
                #print("************* applying import limit of $(Substation_Import_Limit) to the PMD timesteps")
                JuMP.@constraint(m, p_fr[1] .<= Substation_Import_Limit)
                JuMP.@constraint(m, q_fr[1] .<= Substation_Import_Limit) # TODO apply power factor to the import limit for Q
            else
                @constraint(m, sum(m[Symbol("dvGridPurchase_"*Microgrid_Inputs.facility_meter_node)][timestep, tier] for tier in 1:FacilityMeterNode_REoptInputs.s.electric_tariff.n_energy_tiers) <= Substation_Import_Limit)
            end
        end

        if Off_Grid == true || Single_Outage == true || Switches_Open==true
            # Restrict all power flow
            if timestep in PMDTimeSteps_InREoptTimes
                JuMP.@constraint(m, p_fr .== 0)  # The _fr and _to variables are just indicating power flow in either direction on the line. In PMD, there is a constraint that requires  p_to = -p_fr 
                JuMP.@constraint(m, p_to .== 0)  # TODO test removing the "fr" constraints here in order to reduce the # of constraints in the model
                JuMP.@constraint(m, q_fr .== 0)
                JuMP.@constraint(m, q_to .== 0)
            else
                @constraint(m, 
                        sum(m[Symbol("dvGridPurchase_"*Microgrid_Inputs.facility_meter_node)][timestep, tier] for tier in 1:FacilityMeterNode_REoptInputs.s.electric_tariff.n_energy_tiers) == 0)
                @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*Microgrid_Inputs.facility_meter_node)]["PV", u, timestep] for u in FacilityMeterNode_REoptInputs.export_bins_by_tech["PV"]) == 0)
            end
        end
    end
end


function Results_Processing_REopt_PMD_Model(m, results, data_math_mn, REoptInputs_Combined, Microgrid_Inputs)
    # Extract the PMD results
    print("\n Reading the PMD results")
    sol_math = results["solution"]
    # The PMD results are saved to the sol_eng variable
    sol_eng = transform_solution(sol_math, data_math_mn)

    # Extract the REopt results
    print("\n Reading the REopt results")
    REopt_results = reopt_results(m, REoptInputs_Combined)

    DataDictionaryForEachNodeForOutageSimulator = REopt.GenerateInputsForOutageSimulator(Microgrid_Inputs, REopt_results)

    # Compute values for each line and store line power flows in a dataframe and dictionary 
    DataLineFlow = zeros(7)
    DataFrame_LineFlow = DataFrame(fill(Any[],7), [:Line, :Minimum_LineFlow_ActivekW, :Maximum_LineFlow_ActivekW, :Average_LineFlow_ActivekW, :Minimum_LineFlow_ReactivekVAR, :Maximum_LineFlow_ReactivekVAR, :Average_LineFlow_ReactivekVAR ])
    Dictionary_LineFlow_Power_Series = Dict([])

    for line in keys(sol_eng["nw"]["1"]["line"]) # read all of the line names from the first time step
        
        #Phase = 1
        ActivePowerFlow_line_temp = []
        ReactivePowerFlow_line_temp = []
        for i in 1:length(sol_eng["nw"])
            push!(ActivePowerFlow_line_temp, sum(sol_eng["nw"][string(i)]["line"][line]["pf"][Phase] for Phase in keys(sol_eng["nw"][string(i)]["line"][line]["pf"])) )
            push!(ReactivePowerFlow_line_temp, sum(sol_eng["nw"][string(i)]["line"][line]["qf"][Phase] for Phase in keys(sol_eng["nw"][string(i)]["line"][line]["qf"])) )
        end

        DataLineFlow[1] = round(minimum(ActivePowerFlow_line_temp[:]), digits = 5)
        DataLineFlow[2] = round(maximum(ActivePowerFlow_line_temp[:]), digits = 5)
        DataLineFlow[3] = round(mean(ActivePowerFlow_line_temp[:]), digits = 5)
        DataLineFlow[4] = round(minimum(ReactivePowerFlow_line_temp[:]), digits = 5)
        DataLineFlow[5] = round(maximum(ReactivePowerFlow_line_temp[:]), digits = 5)
        DataLineFlow[6] = round(mean(ReactivePowerFlow_line_temp[:]), digits = 5)

        DataFrame_LineFlow_temp = DataFrame([("Line "*string(line)) DataLineFlow[1] DataLineFlow[2] DataLineFlow[3] DataLineFlow[4] DataLineFlow[5] DataLineFlow[6]], [:Line, :Minimum_LineFlow_ActivekW, :Maximum_LineFlow_ActivekW, :Average_LineFlow_ActivekW, :Minimum_LineFlow_ReactivekVAR, :Maximum_LineFlow_ReactivekVAR, :Average_LineFlow_ReactivekVAR])
        DataFrame_LineFlow = append!(DataFrame_LineFlow,DataFrame_LineFlow_temp)
        
        # Also create a dictionary of the line power flows
        Dictionary_LineFlow_Power_Series_temp = Dict([(line, Dict([
                                                            ("ActiveLineFlow", ActivePowerFlow_line_temp),
                                                            ("ReactiveLineFlow", ReactivePowerFlow_line_temp)
                                                        ]))
                                                        ])
        merge!(Dictionary_LineFlow_Power_Series, Dictionary_LineFlow_Power_Series_temp)

    end
    
    return REopt_results, sol_eng, DataDictionaryForEachNodeForOutageSimulator, Dictionary_LineFlow_Power_Series, DataFrame_LineFlow;
end


function Check_REopt_PMD_Alignment(Microgrid_Inputs)
    # Compare the REopt and PMD results to ensure the models are linked
        # Note the calculations below are only valid if there are not any REopt nodes or PMD loads downstream of the node being evaluated
    # TODO: automatically determine which node, line, and phase to check
    Node = 2 # This is for the REopt data
    Line = "line1_2" # This is for the PMD data
    Phase = 1  # This data is for the PMD data

    # Save REopt data to variables for comparison with PMD:
    TotalExport = JuMP.value.(m[Symbol("TotalExport_"*string(Node))]) #[1]
    TotalImport = JuMP.value.(m[Symbol("dvGridPurchase_"*string(Node))]) #[1] If needed, define the time step in the brackets appended to this line

    GridImport_REopt = REopt_results[Node]["ElectricUtility"]["electric_to_storage_series_kw"] + REopt_results[Node]["ElectricUtility"]["electric_to_load_series_kw"] 

    REopt_power_injection = TotalImport - TotalExport

    # Save the power injection data from PMD into a vector for the line
    PowerFlow_line = []
    for i in 1:length(sol_eng["nw"])
        push!(PowerFlow_line, sol_eng["nw"][string(i)]["line"][Line]["pf"][Phase])
    end

    # This calculation compares the power flow through the Line (From PMD), to the power injection into the Node (From REopt). If the PMD and REopt models are connected, this should be zero or very close to zero.
    Mismatch_in_expected_powerflow = PowerFlow_line - REopt_power_injection[1:24].data   # This is only valid for the model with only one REopt load on node 1

    # Visualize the mismatch to ensure the results are zero for each time step
    Plots.plot(collect(1:(Microgrid_Inputs.time_steps_per_hour *8760)), Mismatch_in_expected_powerflow)
    Plots.xlabel!("Timestep")
    Plots.ylabel!("Mismatch between REopt and PMD (kW)")
    display(Plots.title!("REopt and PMD Mismatch: Node $(Node), Phase $(Phase)"))
end 


function GenerateREoptNodesList(Microgrid_Inputs)
    REopt_nodes = []
    for i in Microgrid_Inputs.REopt_inputs_list
        if string(i["Site"]["node"]) != Microgrid_Inputs.facility_meter_node
            push!(REopt_nodes, i["Site"]["node"])
        end
    end
    return REopt_nodes;
end


function GenerateInputsForOutageSimulator(Microgrid_Inputs, REopt_results)
    results = REopt_results
            
            # Temporarily including this code
            #=
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
            =#
            # End of temporarily included code
            
    TimeSteps = collect(1:(8760*Microgrid_Inputs.time_steps_per_hour))
    NodeList = string.(GenerateREoptNodesList(Microgrid_Inputs))
    
    # Define the critical loads
    critical_loads_kw = Dict([])
    if Microgrid_Inputs.critical_load_method == "Fraction"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs.critical_load_fraction[NodeList[i]] * Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method[parse(Int,NodeList[i])]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs.time_steps_per_hour)
            end
        end
    elseif Microgrid_Inputs.critical_load_method == "TimeSeries"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs.critical_load_timeseries[NodeList[i]]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs.time_steps_per_hour)
            end
        end
    else
        throw(@error("Invalid method for generating a critical load was provided"))
    end

    # Initiate the dictionary with data from the first node
    if "ElectricStorage" in keys(results[parse(Int,NodeList[1])])
        if length(results[parse(Int,NodeList[1])]["ElectricStorage"]["soc_series_fraction"]) > 0
            BatteryChargekwh = results[parse(Int,NodeList[1])]["ElectricStorage"]["soc_series_fraction"]*results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kwh"]
            Batterykw = results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kw"]
            Batterykwh = results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kwh"]
        else
            BatteryChargekwh = 0*ones(length(TimeSteps))
            Batterykw = 0
            Batterykwh = 0
        end 
    else
        BatteryChargekwh = 0*ones(length(TimeSteps))
        Batterykw = 0
        Batterykwh = 0
    end 

    if "PV" in keys(results[parse(Int,NodeList[1])])
        if results[parse(Int,NodeList[i])]["PV"]["size_kw"] > 0
            PVProductionProfile_results = round.(((results[parse(Int,NodeList[1])]["PV"]["production_factor_series"])*results[parse(Int,NodeList[1])]["PV"]["size_kw"]), digits = 3)
        else
            PVProductionProfile_results_B = zeros(length(TimeSteps))
        end
    else
        PVProductionProfile_results = zeros(length(TimeSteps))
    end

    if "Generator" in keys(results[parse(Int,NodeList[1])])
        GeneratorSize_results = results[parse(Int,NodeList[1])]["Generator"]["size_kw"]
        if NodeList[1] in keys(Microgrid_Inputs.generator_fuel_gallon_available)
            generator_fuel_gallon_available = Microgrid_Inputs.generator_fuel_gallon_available[NodeList[1]]
        else
            generator_fuel_gallon_available = 0
        end
    else
        GeneratorSize_results = 0
        generator_fuel_gallon_available = 0
    end

    # Enter data into the dictionary
    DataDictionaryForEachNode = Dict([
        (NodeList[1],Dict([
            ("loads_kw", critical_loads_kw[NodeList[1]]), 
            ("PVproductionprofile",  PVProductionProfile_results ),
            ("GeneratorSize", GeneratorSize_results),
            ("Battery_charge_kwh",  BatteryChargekwh),
            ("Battery_kw", Batterykw),
            ("Battery_kwh", Batterykwh),
            ("Fuel_tank_capacity_gal", generator_fuel_gallon_available),
            ("battery_roundtrip_efficiency",0.95)
            ])),
        ])

    # Add additional dictionaries to the main dictionary for the additional nodes, depending on how many nodes there are
    for i in 2:length(NodeList)
        if "ElectricStorage" in keys(results[parse(Int,NodeList[i])]) 
            if length(results[parse(Int,NodeList[i])]["ElectricStorage"]["soc_series_fraction"]) > 0
                BatteryChargekwh_B = results[parse(Int,NodeList[i])]["ElectricStorage"]["soc_series_fraction"]*results[parse(Int,NodeList[i])]["ElectricStorage"]["size_kwh"]
                Batterykw_B = results[parse(Int,NodeList[i])]["ElectricStorage"]["size_kw"]
                Batterykwh_B = results[parse(Int,NodeList[i])]["ElectricStorage"]["size_kwh"]
            else
                BatteryChargekwh_B = 0*ones(length(TimeSteps))
                Batterykw_B = 0
                Batterykwh_B = 0  
            end      
        else 
            BatteryChargekwh_B = 0*ones(length(TimeSteps))
            Batterykw_B = 0
            Batterykwh_B = 0
        end
        if "PV" in keys(results[parse(Int,NodeList[i])])
            if results[parse(Int,NodeList[i])]["PV"]["size_kw"] > 0
                PVProductionProfile_results_B = round.(((results[parse(Int,NodeList[i])]["PV"]["production_factor_series"])*results[parse(Int,NodeList[i])]["PV"]["size_kw"]), digits = 3)
            else
                PVProductionProfile_results_B = zeros(length(TimeSteps))
            end
        else
            PVProductionProfile_results_B = zeros(length(TimeSteps))
        end
        
        if "Generator" in keys(results[parse(Int,NodeList[i])])
            GeneratorSize_results_B = results[parse(Int,NodeList[i])]["Generator"]["size_kw"]
            if NodeList[i] in keys(Microgrid_Inputs.generator_fuel_gallon_available)
                generator_fuel_gallon_available = Microgrid_Inputs.generator_fuel_gallon_available[NodeList[i]]
            else
                generator_fuel_gallon_available = 0
            end 
        else
            GeneratorSize_results_B = 0
            generator_fuel_gallon_available = 0
        end 
        DictionaryToAdd = Dict([
            (NodeList[i],Dict([
                ("loads_kw", critical_loads_kw[NodeList[i]]),
                ("PVproductionprofile", PVProductionProfile_results_B),
                ("GeneratorSize", GeneratorSize_results_B),
                ("Battery_charge_kwh", BatteryChargekwh_B),
                ("Battery_kw", Batterykw_B),
                ("Battery_kwh", Batterykwh_B),
                ("Fuel_tank_capacity_gal", generator_fuel_gallon_available),
                ("battery_roundtrip_efficiency",0.95)
                ])),
        ]) 
        merge!(DataDictionaryForEachNode, DictionaryToAdd)
    end 
return DataDictionaryForEachNode;
end


function Microgrid_OutageSimulator( DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp;
                                    NumberOfOutagesToTest = 15, OutageLength_TimeSteps_Input = 1,
                                    # Inputs for the PMD model: 
                                    pmd_model="", LineInfo_PMD="", data_math_mn="",
                                    # Inputs for the BasicLinear model 
                                    line_max_amps="", lines_rmatrix="", lines_xmatrix="", lines_for_upgrades="", ldf_inputs_dictionary = "",
                                    line_upgrades_each_line="", all_lines="", transformer_max_kva="", BasicLinear_model=""
                                    )
    # Use the function below to run the outage simulator 
    
    NodeList = string.(GenerateREoptNodesList(Microgrid_Inputs))

    OutageLength_TimeSteps = OutageLength_TimeSteps_Input

    NumberOfTimeSteps = Microgrid_Inputs.time_steps_per_hour * 8760
    MaximumTimeStepToEvaluate_limit = NumberOfTimeSteps - (OutageLength_TimeSteps+1) 

    if MaximumTimeStepToEvaluate_limit < NumberOfOutagesToTest
        @warn "The number of possible outages to test is less than the number of outages requested by the user. $(MaximumTimeStepToEvaluate) will be evaluated instead of $(NumberOfOutagesToTest)."
        MaximumTimeStepToEvaluate = MaximumTimeStepToEvaluate_limit
    else
        MaximumTimeStepToEvaluate = NumberOfOutagesToTest
    end

    RunNumber = 0
    SuccessfullySolved = 0
        @info "Number of outages to evaluate: "*string(MaximumTimeStepToEvaluate)

    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
        
        OutageSimulator_LineFromSubstationToFacilityMeter = Microgrid_Inputs.substation_node*"-"*Microgrid_Inputs.facility_meter_node

    elseif Microgrid_Inputs.model_type == "BasicLinear"

        m_outagesimulator = BasicLinear_model

        OutageSimulator_LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Inputs.facility_meter_node

        ldf_inputs_new = PowerFlowInputs(
            ldf_inputs_dictionary["LinesFileLocation"],
            ldf_inputs_dictionary["SubstationLocation"], 
            ldf_inputs_dictionary["LineCodesFileLocation"];
            dsstransformersfilepath = ldf_inputs_dictionary["TransformersFileLocation"],
            Pload = ldf_inputs_dictionary["load_nodes"],
            Qload = ldf_inputs_dictionary["load_nodes"], 
            Sbase = ldf_inputs_dictionary["Sbase_input"],
            Vbase = ldf_inputs_dictionary["Vbase_input"],
            v0 = ldf_inputs_dictionary["v0_input"],  
            v_uplim = ldf_inputs_dictionary["v_uplim_input"],
            v_lolim = ldf_inputs_dictionary["v_lolim_input"],
            P_up_bound = ldf_inputs_dictionary["P_up_bound_input"],  # note, these are not in kW units (they are expressed as a per-unit system)
            P_lo_bound = ldf_inputs_dictionary["P_lo_bound_input"],
            Q_up_bound = ldf_inputs_dictionary["Q_up_bound_input"],
            Q_lo_bound = ldf_inputs_dictionary["Q_lo_bound_input"], 
            Ntimesteps = OutageLength_TimeSteps,

        )
    end

    # Define the outage start time steps based on the number of outages
    IncrementSize_ForOutageStartTimes = Int(floor(MaximumTimeStepToEvaluate_limit/NumberOfOutagesToTest))
    RunsTested = 0
    index = 0
    for x in 1:MaximumTimeStepToEvaluate
        print("\n Outage Simulation Run # "*string(x)*"  of  "*string(MaximumTimeStepToEvaluate)*" runs")
        RunsTested = RunsTested + 1
        i = Int(x*IncrementSize_ForOutageStartTimes)
        TotalTimeSteps = 8760*Microgrid_Inputs.time_steps_per_hour   

        # Generate the power flow constraints
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            # Creates the PMD model and outputs the model itself
            if x != 1
                empty!(m_outagesimulator)  # empty the JuMP model if it has been defined previously
            end
            pm, data_math_mn, data_eng = Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs, OutageLength_TimeSteps; RunningOutageSimulator = true)
            m_outagesimulator = pm.model # TODO: Confirm that when make changes to pm.model again in line 2050 in the function, that that version of pm.model has the additional constraints defined below for m_outagesimulator
            print("\n pm.model Outage simulator model step 1: ")
            show(pm.model)
            print("\n m_outagesimulator Outage simulator model step 1b: ")
            show(m_outagesimulator)

        elseif Microgrid_Inputs.model_type == "BasicLinear"
            empty!(m_outagesimulator) # empties the JuMP model so that the same variables names can be applied in the new model

            m_outagesimulator = JuMP_Model
            power_flow_add_variables(m_outagesimulator, ldf_inputs_new)
            constrain_power_balance(m_outagesimulator, ldf_inputs_new)
            constrain_substation_voltage(m_outagesimulator, ldf_inputs_new)
            create_line_variables(m_outagesimulator, ldf_inputs_new)
            constrain_KVL(m_outagesimulator, ldf_inputs_new, line_upgrades_each_line, lines_for_upgrades, all_lines, Microgrid_Inputs)
        end
        
        for n in NodeList
            GenPowerRating = DataDictionaryForEachNode[n]["GeneratorSize"]  
            TimeSteps = OutageLength_TimeSteps
            time_steps_per_hour = Microgrid_Inputs.time_steps_per_hour
            GalPerkwh = 0.02457 # for the generator 
            FuelTankCapacity =  DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"]
            
            BatteryChargeStart = DataDictionaryForEachNode[n]["Battery_charge_kwh"][i]
            Batterykw = DataDictionaryForEachNode[n]["Battery_kw"]
            Batterykwh = DataDictionaryForEachNode[n]["Battery_kwh"]
            BatteryRoundTripEfficiencyFraction = DataDictionaryForEachNode[n]["battery_roundtrip_efficiency"]


            #print("\n  Total load (kWh) during the outage: "*string(sum(loads)))
            print("\n  Number of time steps evaluated: "*string(TimeSteps))

            # Power export from each node:
            dv = "dvPVToGrid_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
            dv = "dvBatToGrid_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
            dv = "dvBatToGridWithEfficiency_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0) 
            dv = "dvGenToGrid_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)

            # Total power export:
            m_outagesimulator[Symbol("TotalExport_"*n)] = @variable(m_outagesimulator, [1:TimeSteps], base_name=dv) #, lower_bound = 0)
            
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], (m_outagesimulator[Symbol("TotalExport_"*n)] .== m_outagesimulator[Symbol("dvPVToGrid_"*n)][ts] + 
                                                                                                    m_outagesimulator[Symbol("dvBatToGridWithEfficiency_"*n)][ts] + 
                                                                                                    m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts]))

            # Power flow from a node to that node's loads:
            dv = "dvPVToLoad_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0.0)
            dv = "dvBatToLoad_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0.0) #, upper_bound = Batterykw)
            dv = "dvBatToLoadWithEfficiency_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0.0) #, upper_bound = Batterykw)
            dv = "dvGenToLoad_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0.0)
            
            dv = "dvPVToBat_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0.0, upper_bound = Batterykw)

            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvBatToLoadWithEfficiency_"*n)][ts] .== m_outagesimulator[Symbol("dvBatToLoad_"*n)][ts] * BatteryRoundTripEfficiencyFraction)
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvBatToGridWithEfficiency_"*n)][ts] .== m_outagesimulator[Symbol("dvBatToGrid_"*n)][ts] * BatteryRoundTripEfficiencyFraction)

            # Total PV power constraint:
            PVProductionProfile = DataDictionaryForEachNode[n]["PVproductionprofile"]

            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvPVToGrid_"*n)][ts] + 
                                                                m_outagesimulator[Symbol("dvPVToBat_"*n)][ts] + 
                                                                m_outagesimulator[Symbol("dvPVToLoad_"*n)][ts] .<= PVProductionProfile[i.+ts.-1] )
                
            # Grid power import to each node:
            dv = "dvGridToBat_"*n 
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0, upper_bound = Batterykw)
            dv = "dvGridToLoad_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
            dv = "dvGridPurchase_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)    
            dv = "dvTotalGridPurchase_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0 )
            
            @constraint(m_outagesimulator, m_outagesimulator[Symbol("dvTotalGridPurchase_"*n)] .== sum(m_outagesimulator[Symbol("dvGridPurchase_"*n)]) )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvGridPurchase_"*n)] .== 
                                                                m_outagesimulator[Symbol("dvGridToLoad_"*n)][ts] + m_outagesimulator[Symbol("dvGridToBat_"*n)][ts] )
            
            # Generator constraints:
            dv = "FuelUsage_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
            dv = "TotalFuelUsage_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0)
            dv = "FuelLeft_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0)
            
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts] + 
                                                                m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts] .<= 
                                                                GenPowerRating ) 
            @constraint(m_outagesimulator, m_outagesimulator[Symbol("TotalFuelUsage_"*n)] .== sum(m_outagesimulator[Symbol("FuelUsage_"*n)]) )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("FuelUsage_"*n)][ts] .== (m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts] + m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts])*(1/time_steps_per_hour)*GalPerkwh)
            @constraint(m_outagesimulator, sum(m_outagesimulator[Symbol("FuelUsage_"*n)]) .<= DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"] )
            @constraint(m_outagesimulator, m_outagesimulator[Symbol("FuelLeft_"*n)] == DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"]  - m_outagesimulator[Symbol("TotalFuelUsage_"*n)] )
                
            # Battery constraints:
            dv = "BatteryCharge_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv) 
            dv = "SumOfBatFlows_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv)
            
            @constraint(m_outagesimulator, m_outagesimulator[Symbol("BatteryCharge_"*n)][1] == BatteryChargeStart)
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]],  m_outagesimulator[Symbol("SumOfBatFlows_"*n)][ts] .== 
                                                                m_outagesimulator[Symbol("dvBatToLoad_"*n)][ts] + 
                                                                m_outagesimulator[Symbol("dvBatToGrid_"*n)][ts]  - 
                                                                m_outagesimulator[Symbol("dvPVToBat_"*n)][ts] - 
                                                                m_outagesimulator[Symbol("dvGridToBat_"*n)][ts])
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("SumOfBatFlows_"*n)][ts] .<= Batterykw)
            
            for t in 1:(TimeSteps-1)
                @constraint(m_outagesimulator, m_outagesimulator[Symbol("BatteryCharge_"*n)][t+1] ==  m_outagesimulator[Symbol("BatteryCharge_"*n)][t] - 
                                                                                                        (((m_outagesimulator[Symbol("SumOfBatFlows_"*n)][t]))/time_steps_per_hour) )
            end 

            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("BatteryCharge_"*n)][ts] .<= Batterykwh )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("BatteryCharge_"*n)][ts] .>= 0)
            
            # Using a binary to prohibit charging and discharging at the same time:
            dv = "Binary_"*n
            m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, Bin)
            
            for t in 1:TimeSteps
                @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvGridToBat_"*n)][ts] .== 0.0} )
                @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvPVToBat_"*n)][ts] .== 0.0} )
                @constraint(m_outagesimulator, [ts in [1:TimeSteps]], !m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvBatToLoad_"*n)][ts] .== 0.0} )
                @constraint(m_outagesimulator, [ts in [1:TimeSteps]], !m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvBatToGrid_"*n)][ts] .== 0.0} )
            end      
        
            # Power Balance at each node:
            @constraint(m_outagesimulator, [ts in [1:OutageLength_TimeSteps]], m_outagesimulator[Symbol("dvPVToLoad_"*n)][ts] + 
                                                            m_outagesimulator[Symbol("dvGridToLoad_"*n)][ts] +
                                                            m_outagesimulator[Symbol("dvBatToLoadWithEfficiency_"*n)][ts] + 
                                                            m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts] .== round.((DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps-1)]), digits =2)[ts])
            
            print("\n m_outagesimulator Outage simulator model step 2: ")
            show(m_outagesimulator)
        
        end 
        
        # Connect the REopt model and power flow model
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            # Don't need to actually make a REopt model
            
            # Link the power export decision variables to the PMD model
            outage_timesteps = collect(1:OutageLength_TimeSteps_Input)

            REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs)

            gen_name2ind = Dict(gen["name"] => gen["index"] for (_,gen) in data_math_mn["nw"]["1"]["gen"]);
            REopt_gen_ind_e = [gen_name2ind["REopt_gen_$e"] for e in REopt_nodes];
            
            PMD_Pg_ek = [PMD.var(pm, k, :pg, e).data[1] for e in REopt_gen_ind_e, k in outage_timesteps ] # Previously was: PMD_Pg_ek = [PMD.var(pm, k, :pg, REopt_gen_ind_e[e]).data[1] for e in REopt_nodes, k in TimeSteps ]
            PMD_Qg_ek = [PMD.var(pm, k, :qg, e).data[1] for e in REopt_gen_ind_e, k in outage_timesteps]
                
            buses = REopt_nodes
            
            for e in REopt_gen_ind_e  #Note: the REopt_gen_ind_e does not contain the facility meter
                JuMP.@constraint(pm.model, [k in outage_timesteps],  
                                    PMD_Pg_ek[e,k] == pm.model[Symbol("TotalExport_"*string(buses[e]))][k] - pm.model[Symbol("dvGridPurchase_"*string(buses[e]))][k]   # negative power "generation" is a load
                )
                # TODO: add reactive power to the REopt nodes
                JuMP.@constraint(pm.model, [k in outage_timesteps],
                                    PMD_Qg_ek[e,k] == 0.0 #m[Symbol("TotalExport_"*string(buses[e]))][k] - m[Symbol("dvGridPurchase_"*string(buses[e]))][k] 
                )
            end

            # Prevent power from entering the microgrid to simulate a power outage
            for PMD_time_step in outage_timesteps
                i = LineInfo_PMD[Microgrid_Inputs.substation_line]["index"]
                timestep_for_network_data = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
                branch = ref(pm, timestep_for_network_data, :branch, i)
                f_bus = branch["f_bus"]
                t_bus = branch["t_bus"]
                f_connections = branch["f_connections"]
                t_connections = branch["t_connections"]
                f_idx = (i, f_bus, t_bus)
                t_idx = (i, t_bus, f_bus)

                p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
                p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]

                q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
                q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]

                JuMP.@constraint(pm.model, p_fr .== 0)  # The _fr and _to variables are just indicating power flow in either direction on the line. In PMD, there is a constraint that requires  p_to = -p_fr 
                JuMP.@constraint(pm.model, p_to .== 0)  # TODO test removing the "fr" constraints here in order to reduce the # of constraints in the model
                JuMP.@constraint(pm.model, q_fr .== 0)
                JuMP.@constraint(pm.model, q_to .== 0)
            end


        elseif Microgrid_Inputs.model_type == "BasicLinear"
            # Constrain the loads
            constrain_loads(m_outagesimulator, ldf_inputs_new, REopt_dictionary) 
            
            # Define the parameters of the lines
            for j in ldf_inputs_new.busses
                for i in i_to_j(j, ldf_inputs_new)
                    i_j = string(i*"-"*j)
                    JuMP.@constraint(m_outagesimulator, m_outagesimulator[:line_max_amps][i_j] .== line_max_amps[i_j])
                    
                    # Define the new xmatrix and rmatrix for any upgradable lines
                    if Microgrid_Inputs.model_line_upgrades == true && Microgrid_Inputs.nonlinear_solver == true
                        if i_j in lines_for_upgrades
                            @constraint(m_outagesimulator, m_outagesimulator[:line_rmatrix][i_j] == lines_rmatrix[i_j])
                            @constraint(m_outagesimulator, m_outagesimulator[:line_xmatrix][i_j] == lines_xmatrix[i_j])
                        end
                    end
                end
            end

            # Define the max power through the transformers
            for i in keys(ldf_inputs_new.transformers)
                if ldf_inputs_new.transformers[i]["Transformer Side"] == "downstream"
                    JuMP.@constraint(m_outagesimulator, m_outagesimulator[:transformer_max_kva][i] .== transformer_max_kva[i] ) #value.(model[:transformer_max_kva][i]))
                end
            end

            # Prevent power from entering the microgrid (to represent a power outage)
            JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ][OutageSimulator_LineFromSubstationToFacilityMeter,t] .>= 0 ) 
            JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ][OutageSimulator_LineFromSubstationToFacilityMeter,t] .<= 0.001)

        end

        # Determine all of the nodes with PV
        NodesWithPV = []
        for p in NodeList 
            if maximum(DataDictionaryForEachNode[p]["PVproductionprofile"]) > 0
                push!(NodesWithPV, p)
            end
        end 

        # Objective function, which is formulated to maximize the PV power that is used to meet the load
        @objective(pm.model, Max, sum(sum(m_outagesimulator[Symbol(string("dvPVToLoad_", n))]) for n in NodesWithPV))
        
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            set_optimizer(pm.model, Microgrid_Inputs.optimizer) 
            
            if Microgrid_Inputs.optimizer == Xpress.Optimizer
                set_optimizer_attribute(m_outagesimulator, "MIPRELSTOP", Microgrid_Inputs.optimizer_tolerance)
            elseif Microgrid_Inputs.optimizer == Gurobi.Optimizer
                set_optimizer_attributes(m_outagesimulator, "MIPGap", Microgrid_Inputs.optimizer_tolerance)
            else
                @info "The solver's default tolerance is being used for the optimization"
            end

            print("\n Outage Simulator Outage simulator model step 3: ")
            show(m_outagesimulator)
            
            print("\n pm.model Outage simulator model step 4: ")
            show(pm.model)
            results = PMD.optimize_model!(pm) 
            TerminationStatus = string(results["termination_status"])
            print("\n The result from run #"*string(RunsTested)*" is: "*TerminationStatus)
        elseif Microgrid_Inputs.model_type == "BasicLinear"
            runresults = optimize!(m_outagesimulator)
            TerminationStatus = string(termination_status(m_outagesimulator))
            print("\n The result from run #"*string(RunsTested)*" is: "*TerminationStatus)
        end

        if TerminationStatus == "OPTIMAL"
            SuccessfullySolved = SuccessfullySolved + 1

            # TODO: change the calculation of the fuel remaining so it automatically calculates the fuel left on nodes with generators
            #print("\n the fuel left is: "*string(value.(m_outagesimulator[Symbol("FuelLeft_3")]) +
            #value.(m_outagesimulator[Symbol("FuelLeft_4")]) +
            #value.(m_outagesimulator[Symbol("FuelLeft_6")]) +
            #value.(m_outagesimulator[Symbol("FuelLeft_10")])) * " gal")
                    
            if Microgrid_Inputs.generate_results_plots == true
                @info "Generating results plots from the outage simulator, if the defined run numbers for creating plots survived the outage"

                # Generate plots for the outage simulator run numbers defined in the Microgrid_Inputs dictionary 
                if x in Microgrid_Inputs.run_numbers_for_plotting_outage_simulator_results
                    mkdir(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)")
                    # plot the dispatch for each of the REopt nodes for the outage that is being tested
                    for n in NodeList
                        Plots.plot(value.(m_outagesimulator[Symbol("dvPVToLoad_"*n)]), label = "PV to Load", linewidth = 3)
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToLoad_"*n)]), label = "Gen to Load", linewidth = 3)
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load", linewidth = 3)
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToLoad_"*n)]), label = "Grid to Load", linewidth = 3)
                        Plots.plot!(DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps-1)], label = "Total Load", linecolor = (:black), line = (:dash), linewidth = 3)
                        Plots.xlabel!("Time Step") 
                        Plots.ylabel!("Power (kW)") 
                        display(Plots.title!("Node "*n*": Load Balance, outage timestep: "*string(i)*" of "*string(TotalTimeSteps)))
                        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Load_Balance_"*TimeStamp*".png")
                    end 
                
                    # Plots results for each node during the outage
                    for n in NodeList
                        # Plot the power export
                        Plots.plot(value.(m_outagesimulator[Symbol("dvPVToGrid_"*n)]), label = "PV to Grid")
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToGrid_"*n)]), label = "Gen to Grid")
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
                        Plots.xlabel!("Time Step")
                        Plots.ylabel!("Power (kW)")
                        display(Plots.title!("Node "*n*": Power Export, outage timestep "*string(i)*" of "*string(TotalTimeSteps)))
                        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Power_Export_"*TimeStamp*".png")
                    
                        # Plot the battery flows
                        Plots.plot(-value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load")
                        Plots.plot!(-value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToBat_"*n)]), label = "Grid to Battery")
                        Plots.plot!(value.(m_outagesimulator[Symbol("dvPVToBat_"*n)]), label = "PV to Battery")
                        Plots.xlabel!("Time Step")
                        Plots.ylabel!("Power (kW)")
                        display(Plots.title!("Node "*n*": Battery Flows, outage "*string(i)*" of "*string(TotalTimeSteps)))
                        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Flows_"*TimeStamp*".png")
                    
                        # Plot the battery charge:
                        Plots.plot(value.(m_outagesimulator[Symbol("BatteryCharge_"*n)]), label = "Battery Charge")
                        Plots.xlabel!("Time Step")
                        Plots.ylabel!("Charge (kWh)")
                        display(Plots.title!("Node "*n*": Battery Charge, outage "*string(i)*" of "*string(TotalTimeSteps)))
                        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Charge_"*TimeStamp*".png")
                    
                    end
                end 
            end
        end 
        print("\n  Outages survived so far: "*string(SuccessfullySolved)*", Outages tested so far: "*string(RunsTested))
    end

    print("\n --- Summary of results ---")
    RunNumber = MaximumTimeStepToEvaluate 
    PercentOfOutagesSurvived = 100*(SuccessfullySolved/RunNumber)
    print("\n The length of outage tested is: "*string(OutageLength_TimeSteps)*" time steps")
    print("\n The number of outages survived is: "*string(SuccessfullySolved)*"  of  "*string(RunNumber)*" runs")
    print("\n Percent of outages survived: "*string(round(PercentOfOutagesSurvived, digits = 2))*" % \n")

    return OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived, m_outagesimulator
end 


function Results_Compilation(model, results, Outage_Results, Microgrid_Inputs, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; system_results_BAU = "", line_upgrade_results = "", transformer_upgrade_results = "")

    InputsList = Microgrid_Inputs.REopt_inputs_list

    # Compute system-level outputs
    system_results = Dict{String, Any}() # Float64}()
    
    total_lifecycle_cost = 0
    total_lifecycle_capital_cost = 0 # includes replacements and incentives
    total_initial_capital_costs = 0
    total_initial_capital_costs_after_incentives = 0
    total_lifecycle_storage_capital_costs = 0
    total_PV_size_kw = 0
    total_PV_energy_produced_minus_curtailment_first_year = 0
    total_electric_storage_size_kw = 0
    total_electric_storage_size_kwh = 0
    total_generator_size_kw = 0

    for n in InputsList 
        node_temp = n["Site"]["node"]

        total_lifecycle_cost = total_lifecycle_cost + results[node_temp]["Financial"]["lcc"]
        total_lifecycle_capital_cost = total_lifecycle_capital_cost + results[node_temp]["Financial"]["lifecycle_capital_costs"]
        total_initial_capital_costs = total_initial_capital_costs + results[node_temp]["Financial"]["initial_capital_costs"]
        total_initial_capital_costs_after_incentives = total_initial_capital_costs_after_incentives + results[node_temp]["Financial"]["initial_capital_costs_after_incentives"] 
        total_lifecycle_storage_capital_costs = total_lifecycle_storage_capital_costs + results[node_temp]["Financial"]["lifecycle_storage_capital_costs"]

        if "PV" in keys(results[node_temp])
            total_PV_size_kw = total_PV_size_kw + results[node_temp]["PV"]["size_kw"]
            total_PV_energy_produced_minus_curtailment_first_year = total_PV_energy_produced_minus_curtailment_first_year + 
                                                                    (results[node_temp]["PV"]["year_one_energy_produced_kwh"] - sum(results[node_temp]["PV"]["electric_curtailed_series_kw"]/Microgrid_Inputs.time_steps_per_hour))
        end
        if "ElectricStorage" in keys(results[node_temp])
            total_electric_storage_size_kw = total_electric_storage_size_kw + results[node_temp]["ElectricStorage"]["size_kw"]
            total_electric_storage_size_kwh = total_electric_storage_size_kwh + results[node_temp]["ElectricStorage"]["size_kwh"]
        end
        if "Generator" in keys(results[node_temp])
            total_generator_size_kw = total_generator_size_kw + results[node_temp]["Generator"]["size_kw"]
        end
    end

    system_results["total_lifecycle_cost"] = total_lifecycle_cost
    system_results["total_lifecycle_capital_cost"] = total_lifecycle_capital_cost
    system_results["total_initial_capital_costs"] = total_initial_capital_costs
    system_results["total_initial_capital_costs_after_incentives"] =  total_initial_capital_costs_after_incentives
    system_results["total_lifecycle_storage_capital_cost"] = total_lifecycle_storage_capital_costs
    system_results["total_PV_size_kw"] = total_PV_size_kw
    system_results["total_PV_energy_produced_minus_curtailment_first_year"] = total_PV_energy_produced_minus_curtailment_first_year
    system_results["total_electric_storage_size_kw"] = total_electric_storage_size_kw
    system_results["total_electric_storage_size_kwh"] = total_electric_storage_size_kwh
    system_results["total_generator_size_kw"] = total_generator_size_kw

    if system_results_BAU != ""
        system_results["net_present_value"] = system_results_BAU["total_lifecycle_cost"] - total_lifecycle_cost
    else
        system_results["net_present_value"] = "Not calculated"
    end

    # Generate a csv file with outputs from the model if the "generate_CSV_of_outputs" field is set to true
    if system_results_BAU != ""
    if Microgrid_Inputs.generate_CSV_of_outputs == true
        @info "Generating CSV of outputs"
        DataLabels = []
        Data = []
        
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            LineFromSubstationToFacilityMeter = "line"*Microgrid_Inputs.substation_node * "_" * Microgrid_Inputs.facility_meter_node

            MaximumPowerOnsubstation_line_ActivePower = (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))
            MinimumPowerOnsubstation_line_ActivePower = (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))
            AveragePowerOnsubstation_line_ActivePower = (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))

            MaximumPowerOnsubstation_line_ReactivePower = (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))
            MinimumPowerOnsubstation_line_ReactivePower = (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))
            AveragePowerOnsubstation_line_ReactivePower = (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))

        elseif Microgrid_Inputs.model_type == "BasicLinear"
            LineFromSubstationToFacilityMeter = Microgrid_Inputs.substation_node * "-" * Microgrid_Inputs.facility_meter_node

            MaximumPowerOnsubstation_line_ActivePower = (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
            MinimumPowerOnsubstation_line_ActivePower = (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
            AveragePowerOnsubstation_line_ActivePower = (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
            
            # Temporarily not recording the reactive power through the lines:
            MaximumPowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
            MinimumPowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
            AveragePowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
        
        end

        # Add system-level results

        push!(DataLabels, "----Optimization Parameters----")
        push!(Data,"")
        push!(DataLabels, "  Number of Variables")
        push!(Data, length(all_variables(model)))
        push!(DataLabels, "  Computation time, including the BAU model and the outage simulator if used (minutes)")
        push!(Data, round((Dates.value(ComputationTime_EntireModel)/(1000*60)), digits=2))

        
        push!(DataLabels, "----System Results----")
        push!(Data,"")

        push!(DataLabels,"  Total Lifecycle Cost (LCC)")
        push!(Data, round(system_results["total_lifecycle_cost"], digits=0))
        push!(DataLabels,"  Total Lifecycle Capital Cost (LCCC)")
        push!(Data, round(system_results["total_lifecycle_capital_cost"], digits=0))

        push!(DataLabels,"  Net Present Value (NPV)")
        push!(Data, round(system_results["net_present_value"], digits=0))
        
        push!(DataLabels,"  Total initial capital costs")
        push!(Data, round(system_results["total_initial_capital_costs"],digits=0))
        push!(DataLabels,"Total initial capital costs after incentives")
        push!(Data, round(system_results["total_initial_capital_costs_after_incentives"],digits=0))

        push!(DataLabels,"  Total lifecycle storage capital cost")
        push!(Data, round(system_results["total_lifecycle_storage_capital_cost"],digits=0))
        push!(DataLabels,"  Total PV size kw")
        push!(Data, round(system_results["total_PV_size_kw"],digits=0))

        push!(DataLabels,"  Total PV energy produced minus curtailment first year")
        push!(Data,  round(system_results["total_PV_energy_produced_minus_curtailment_first_year"],digits=0))
        push!(DataLabels,"  Total electric storage size kw")
        push!(Data, round(system_results["total_electric_storage_size_kw"],digits=0))
        
        push!(DataLabels,"  Total electric storage size kwh")
        push!(Data, round(system_results["total_electric_storage_size_kwh"],digits=0))
        push!(DataLabels,"  Total generator size kw")
        push!(Data, round(system_results["total_generator_size_kw"],digits=0))
        

        push!(DataLabels, "----Power Flow Model Results----")
        push!(Data, "")
        push!(DataLabels,"  Maximum power flow on substation line, Active Power kW")
        push!(Data, MaximumPowerOnsubstation_line_ActivePower)
        push!(DataLabels,"  Minimum power flow on substation line, Active Power kW")
        push!(Data, MinimumPowerOnsubstation_line_ActivePower)
        push!(DataLabels,"  Average power flow on substation line, Active Power kW")
        push!(Data, AveragePowerOnsubstation_line_ActivePower)

        push!(DataLabels,"  Maximum power flow on substation line, Reactive Power kVAR")
        push!(Data, MaximumPowerOnsubstation_line_ReactivePower)
        push!(DataLabels,"  Minimum power flow on substation line, Reactive Power kVAR")
        push!(Data, MinimumPowerOnsubstation_line_ReactivePower)
        push!(DataLabels,"  Average power flow on substation line, Reactive Power kVAR")
        push!(Data, AveragePowerOnsubstation_line_ReactivePower)
        
        # Add the microgrid outage results to the dataframe
        push!(DataLabels, "----Microgrid Outage Results----")
        push!(Data, "")
        if Microgrid_Inputs.run_outage_simulator == true
            for i in 1:length(Microgrid_Inputs.length_of_simulated_outages_time_steps)
                OutageLength = Microgrid_Inputs.length_of_simulated_outages_time_steps[i]
                push!(DataLabels, " --Outage Length: $(OutageLength) time steps--")
                push!(Data, "")
                push!(DataLabels, "  Percent of Outages Survived")
                push!(Data, string(Outage_Results["$(OutageLength)_timesteps_outage"]["PercentSurvived"])*" %")
                push!(DataLabels, "  Total Number of Outages Tested")
                push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfRuns"])
                push!(DataLabels, "  Total Number of Outages Survived")
                push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfOutagesSurvived"])
            end 
        else 
            push!(DataLabels,"Outage modeling was not run")
            push!(Data,"")
        end

        # Add results for each REopt node
        push!(DataLabels, "----REopt Results for Each Node----")
        push!(Data, "")
        
        for n in InputsList 
            NodeNumberTempB = n["Site"]["node"]
            InputsDictionary = Dict[] # reset the inputs dictionary to an empty dictionary before redefining
            InputsDictionary = n
            push!(DataLabels, "--Node $(NodeNumberTempB)")
            push!(Data, "")

            if "PV" in keys(results[NodeNumberTempB])
                push!(DataLabels, "  PV Size (kw)")
                push!(Data, results[NodeNumberTempB]["PV"]["size_kw"])
                push!(DataLabels, "  Min and Max PV sizing input, kW")
                push!(Data, string(InputsDictionary["PV"]["min_kw"])*" and "*string(InputsDictionary["PV"]["max_kw"]))

                push!(DataLabels, "  Max PV Power Curtailed: ") 
                push!(Data, round(maximum(results[NodeNumberTempB]["PV"]["electric_curtailed_series_kw"]), digits =2))
                push!(DataLabels, "  Max PV Power Exported to Grid from node: ") 
                push!(Data,round(maximum(results[NodeNumberTempB]["PV"]["electric_to_grid_series_kw"]), digits =2))
            else
                push!(DataLabels, "  PV")
                push!(Data, " None")
            end 
        
            if "Generator" in keys(results[NodeNumberTempB])
                push!(DataLabels, "  Generator (kw)")
                push!(Data, round(results[NodeNumberTempB]["Generator"]["size_kw"], digits =2))
                
                push!(DataLabels, "  Maximum generator power to load (kW): ")
                push!(Data, round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2))
                push!(DataLabels, "  Average generator power to load (kW): ")
                push!(Data, round(mean(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2))
                
                push!(DataLabels, "  Maximum generator power to grid (kW): ")
                push!(Data, round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2))
                push!(DataLabels, "  Minimum generator power to grid (kW): ")
                push!(Data, round(minimum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2))
                
                push!(DataLabels, "  Average generator power to grid (kW): ")
                push!(Data, round(mean(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2))
            else 
                push!(DataLabels, "  Generator")
                push!(Data, " None")   
            end 
            if "ElectricStorage" in keys(results[NodeNumberTempB])
                if results[NodeNumberTempB]["ElectricStorage"]["size_kw"] > 0 
                    push!(DataLabels, "  Battery Power (kW)")
                    push!(Data, round(results[NodeNumberTempB]["ElectricStorage"]["size_kw"], digits =2)) 
                    push!(DataLabels, "  Battery Capacity (kWh)")
                    push!(Data, round(results[NodeNumberTempB]["ElectricStorage"]["size_kwh"], digits =2))
                    
                    push!(DataLabels, "  Average Battery SOC (fraction): ")
                    push!(Data, round(mean(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2))
                    push!(DataLabels, "  Minimum Battery SOC (fraction): ")
                    push!(Data, round(minimum(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2))
                    
                    push!(DataLabels, "  Average battery to load (kW): ")
                    push!(Data, round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2))
                    push!(DataLabels, "  Maximum battery to load (kW): ")
                    push!(Data, round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2))
                    
                    push!(DataLabels, "  Average battery to grid (kW): ")
                    push!(Data, round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2))
                    push!(DataLabels, "  Maximum battery to grid (kW): ")
                    push!(Data, round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2))
                else
                    push!(DataLabels, "  Battery")
                    push!(Data, " None")   
                end
            else
                push!(DataLabels, "  Battery")
                push!(Data, " None")   
            end 
        end
               
        # Save the dataframe as a csv document
        dataframe_results = DataFrame(Labels = DataLabels, Data = Data)
        CSV.write(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Summary_"*TimeStamp*".csv", dataframe_results)
        
        # Save the Line Flow summary to a different csv
        CSV.write(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Line_Flow_Summary_"*TimeStamp*".csv", DataFrame_LineFlow_Summary)
        
        # Save line upgrade results to a csv 
        if Microgrid_Inputs.model_line_upgrades
            CSV.write(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Line_Upgrade_Summary_"*TimeStamp*".csv", dataframe_line_upgrade_summary)
        end

        # Save the transformer upgrade results to a csv
        if Microgrid_Inputs.model_transformer_upgrades
            CSV.write(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Transformer_Upgrade_Summary_"*TimeStamp*".csv", dataframe_transformer_upgrade_summary)
        end
    end 

    #Display results if the "display_results" input is set to true
    if Microgrid_Inputs.display_results == true
        print("\n-----")
        print("\nResults:") 
        print("\n   The computation time was: "*string(ComputationTime_EntireModel))
    
        print("Line Flow Results")
        display(DataFrame_LineFlow_Summary)
    
        print("\nSubstation data: ")
        print("\n   Maximum active power flow from substation, kW: "*string(MaximumPowerOnsubstation_line_ActivePower))
        print("\n   Minimum active power flow from substation, kW: "*string(MinimumPowerOnsubstation_line_ActivePower))
        print("\n   Average active power flow from substation, kW: "*string(AveragePowerOnsubstation_line_ActivePower))
    
        print("\n   Maximum reactive power flow from substation, kVAR: "*string(MaximumPowerOnsubstation_line_ReactivePower))
        print("\n   Minimum reactive power flow from substation, kVAR: "*string(MinimumPowerOnsubstation_line_ReactivePower))
        print("\n   Average reactive power flow from substation, kVAR: "*string(AveragePowerOnsubstation_line_ReactivePower))

        # Print results for each node:
        for n in InputsList 
            NodeNumberTempB = n["Site"]["node"]
            InputsDictionary = Dict[] # reset the inputs dictionary to an empty dictionary before redefining
            InputsDictionary = n
            print("\nNode "*string(NodeNumberTempB)*":")
            
            if "PV" in keys(results[NodeNumberTempB])
                print("\n   PV Size (kW): "*string(results[NodeNumberTempB]["PV"]["size_kw"]))
                print("\n      Min and Max sizing is (input to model), kW: "*string(InputsDictionary["PV"]["min_kw"])*" and "*string(InputsDictionary["PV"]["max_kw"]))
                print("\n      Max PV Power Curtailed: "*string(round(maximum(results[NodeNumberTempB]["PV"]["electric_curtailed_series_kw"]), digits =2)))
                print("\n      Max PV Power Exported to Grid from node: "*string(round(maximum(results[NodeNumberTempB]["PV"]["electric_to_grid_series_kw"]), digits =2))) 
            else
                print("\n   No PV")
            end 
    
            if "Generator" in keys(results[NodeNumberTempB])
                print("\n  Generator size (kW): "*string(round(results[NodeNumberTempB]["Generator"]["size_kw"], digits =2)))
                print("\n     Maximum generator power to load (kW): "*string(round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2)))
                print("\n       Average generator power to load (kW): "*string(round(mean(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2)))
                print("\n     Maximum generator power to grid (kW): "*string(round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
                print("\n       Minimum generator power to grid (kW): "*string(round(minimum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
                print("\n       Average generator power to grid (kW): "*string(round(mean(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
            else 
                print("\n  No generator")    
            end 
            if "ElectricStorage" in keys(results[NodeNumberTempB])
                if results[NodeNumberTempB]["ElectricStorage"]["size_kw"] > 0 
                    print("\n  Battery power (kW): "*string(round(results[NodeNumberTempB]["ElectricStorage"]["size_kw"], digits =2)))
                    print("\n    Battery capacity (kWh): "*string(round(results[NodeNumberTempB]["ElectricStorage"]["size_kwh"], digits =2)))
                    print("\n    Average Battery SOC (fraction): "*string(round(mean(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
                    print("\n      Minimum Battery SOC (fraction): "*string(round(minimum(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
                    print("\n    Average battery to load (kW): "*string(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
                    print("\n      Maximum battery to load (kW): "*string(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
                    print("\n    Average battery to grid (kW): "*string(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
                    print("\n      Maximum battery to grid (kW): "*string(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
                else
                    print("\n  No battery")
                end
            else
                print("\n  No battery")
            end 
        end
        print("\n----") 
    end 
end
    return system_results;    
end


function CreateResultsMap(results, Microgrid_Inputs, TimeStamp)

    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
        lines = keys(results["Line_Info_PMD"])
    elseif Microgrid_Inputs.model_type == "BasicLinear"
        lines = keys(results["FromREopt_Dictionary_LineFlow_Power_Series"])
    end

    # Extract the latitude and longitude for the busses
    bus_coordinates_filename = Microgrid_Inputs.bus_coordinates
    data_input = CSV.read(bus_coordinates_filename, DataFrame, header =1)
    latitudes = vec(Matrix(data_input[:,[:Latitude]]))
    longitudes = vec(Matrix(data_input[:,[:Longitude]]))
    busses = vec(Matrix(data_input[:,[:Bus]]))

    # Create a dictionary of the bus coordinates
    bus_cords = Dict([])
    for i in 1:length(busses)
        bus_cords[string(busses[i])] = [latitudes[i], longitudes[i]]
    end

    # Create a dictionary of the line segment start and end coordinates
    line_cords = Dict([])
    for i in keys(bus_cords)
        for x in keys(bus_cords)
            if i != x
                if "line"*i*"_"*x in lines
                    line_cords["line"*i*"_"*x] = [bus_cords[i],bus_cords[x]]
                end
            end
        end
    end
    
    bus_key_values = collect(keys(bus_cords))
    line_key_values = collect(keys(line_cords))

    # Create a dictionary of the technology sizing at each node, which will be plotted on the map:
    results_by_node = Dict([])
    for i in busses 
        if i in keys(results["REopt_results"])
            if "PV" in keys(results["REopt_results"][i])
                if results["REopt_results"][i]["PV"]["size_kw"] > 0
                    PV = "PV: "*string(round(results["REopt_results"][i]["PV"]["size_kw"], digits=0))
                else
                    PV = ""  
                end
            else            
                PV = ""
            end

            if "Generator" in keys(results["REopt_results"][i])
                if results["REopt_results"][i]["Generator"]["size_kw"] > 0
                    Generator = "Gen: "*string(round(results["REopt_results"][i]["Generator"]["size_kw"], digits=0))
                else
                    Generator = ""
                end
            else
                Generator = ""
            end

            if "ElectricStorage" in keys(results["REopt_results"][i])
                if results["REopt_results"][i]["ElectricStorage"]["size_kw"] > 0
                    Battery =  "Bat: "*string(round(results["REopt_results"][i]["ElectricStorage"]["size_kw"],digits=1))*"kW"*","*string(round(results["REopt_results"][i]["ElectricStorage"]["size_kwh"],digits=1))*"kWh"
                else
                    Battery = ""
                end
            else
                Battery = ""
            end
            
            if PV != "" || Generator != "" || Battery != ""
                punctuation = ": "
            else
                punctuation = ""
            end
            
            results_by_node[string(i)] = punctuation*PV*Generator*Battery
        else
            results_by_node[string(i)] = ""
        end
    end

    traces = PlotlyJS.GenericTrace[] # initiate the vector as a vector of PlotlyJS traces

    # Add traces for the nodes
    for i in 1:length(bus_key_values)
        trace_bus = PlotlyJS.scattergeo(;locationmode = "USA-states",
                        lat = [bus_cords[bus_key_values[i]][1]],
                        lon = [bus_cords[bus_key_values[i]][2]],
                        marker_size = 8,
                        marker_color = "blue",
                        mode = "markers+text",
                        text = bus_key_values[i]*results_by_node[bus_key_values[i]], # Show the technology sizing next to each node
                        textposition = "right"
                        )
        push!(traces, trace_bus)
    end

    # Add traces for the lines
    for i in 1:length(line_key_values)
        trace_line     = PlotlyJS.scattergeo(;locationmode = "USA-states",
                    lat = [line_cords[line_key_values[i]][1][1], line_cords[line_key_values[i]][2][1]],
                    lon = [line_cords[line_key_values[i]][1][2], line_cords[line_key_values[i]][2][2]],
                    mode = "lines",
                    line_color = "black",
                    line_width = 2) 
        push!(traces, trace_line)
    end
    geo = PlotlyJS.attr(scope = "usa",
                projection_type = "albers usa",
                showland = true,
                landcolor = "rgb(217,217,217)",
                subunitwidth =1,
                countrywidth=1,
                fitbounds = "locations",
                subunitcolor = "rgb(255,255,255)",
                countrycolor = "rgb(255,255,255)")
    layout = PlotlyJS.Layout(; title="Microgrid Results and Layout", geo=geo,  showlegend = false)
    
    p = PlotlyJS.plot(traces,layout)
    PlotlyJS.savefig(p, Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_and_Layout.html")
    display(p)

end



function Aggregated_PowerFlows_Plot(results, TimeStamp, Microgrid_Inputs, REoptInputs_Combined, model)
    # Function to create additional plots using PlotlyJS
    
    OutageStartTimeStep = Microgrid_Inputs.single_outage_start_time_step
    OutageStopTimeStep = Microgrid_Inputs.single_outage_end_time_step

    NodeList = []
    for i in Microgrid_Inputs.REopt_inputs_list
        push!(NodeList, i["Site"]["node"])
    end

    TotalLoad_series = zeros(Microgrid_Inputs.time_steps_per_hour * 8760) # initiate the total load as 0
    for n in NodeList
        TotalLoad_series = TotalLoad_series + results["REopt_results"][n]["ElectricLoad"]["load_series_kw"] 
    end

    # determine all of the nodes with PV and determine total PV output across the entire network
    NodesWithPV = []
    for i in keys(results["REopt_results"])
        if "PV" in keys(results["REopt_results"][i])
            push!(NodesWithPV, i)
        end
    end
    #print("\n The nodes with PV are: ")
    #print(NodesWithPV)

    # TODO: account for the situation where one node might be exporting PV and then another node might use that power to charge a battery
    PVOutput = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
    for NodeNumberTemp in NodesWithPV
        PVOutput = PVOutput + results["REopt_results"][NodeNumberTemp]["PV"]["electric_to_load_series_kw"] + results["REopt_results"][NodeNumberTemp]["PV"]["electric_to_grid_series_kw"]
    end

    # determine all of the nodes with Battery
    NodesWithBattery = []
    for i in keys(results["REopt_results"])
        if "ElectricStorage" in keys(results["REopt_results"][i])
            push!(NodesWithBattery, i)
        end
    end
    BatteryOutput = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
    for NodeNumberTemp in NodesWithBattery
        if results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["size_kw"] > 0  # include this if statement to prevent trying to add in empty electric storage time series vectors
            BatteryOutput = BatteryOutput + results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"] + results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"] 
        end
    end

    # determine all of the nodes with generator
    NodesWithGenerator = []
    for i in keys(results["REopt_results"])
        if "Generator" in keys(results["REopt_results"][i])
            push!(NodesWithGenerator, i)
        end
    end
    GeneratorOutput = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
    for NodeNumberTemp in NodesWithGenerator
        GeneratorOutput = GeneratorOutput + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_load_series_kw"].data + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"].data  # + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_storage_series_kw"].data 
    end
    
    # Save the REopt Inputs for the site not to a variable
    print("\n The facility meter node REopt inputs are being recorded")
    FacilityMeterNode_REoptInputs = ""
    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            FacilityMeterNode_REoptInputs = p        
        end
    end
    print("\n The facility meter node REopt inputs have been recorded")
    
    # Save power input from the grid to a variable for plotting
    PowerFromGrid = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
    if Microgrid_Inputs.model_type == "PowerModelsDistribution"    
        PowerFromGrid = value.(model[Symbol("dvSubstationPowerFlow")]).data  
    elseif Microgrid_Inputs.model_type == "BasicLinear"
        PowerFromGrid = results["FromREopt_Dictionary_LineFlow_Power_Series"]["0-15"]["NetRealLineFlow"]
    end 
    print("\n The grid power has been recorded")
    
    
    #Plot the network-wide power use 
    print("\n Making the static plot")
    
    # Static plot
    days = collect(1:(Microgrid_Inputs.time_steps_per_hour * 8760))/(Microgrid_Inputs.time_steps_per_hour * 24)
    Plots.plot(days, TotalLoad_series, label="Total Load")
    Plots.plot!(days, PVOutput, label="Combined PV Output")
    Plots.plot!(days, BatteryOutput, label = "Combined Battery Output")
    Plots.plot!(days, GeneratorOutput, label = "Combined Generator Output")
    Plots.plot!(days, PowerFromGrid, label = "Grid Power")
    if (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/24
        OutageStop_Line = OutageStopTimeStep/24
        Plots.plot!([OutageStart_Line, OutageStart_Line],[0,maximum(TotalLoad_series)], label= "Outage Start")
        Plots.plot!([OutageStop_Line, OutageStop_Line],[0,maximum(TotalLoad_series)], label= "Outage End")
        Plots.xlims!(OutageStartTimeStep-12, OutageStopTimeStep+12)
    else
        Plots.xlims!(100,104)
    end
    display(Plots.title!("System Wide Power Demand and Generation"))
    print("\n The static plot has been generated")

    # Interactive plot using PlotlyJS
    traces = PlotlyJS.GenericTrace[]
    layout = PlotlyJS.Layout(title_text = "System Wide Power Demand and Generation", xaxis_title_text = "Day", yaxis_title_text = "Power (kW)")
    
    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
        
        max = 1.1 * maximum([maximum(TotalLoad_series), maximum(PVOutput), maximum(BatteryOutput), maximum(GeneratorOutput), maximum(PowerFromGrid)])
        min = 1.1 * minimum([minimum(TotalLoad_series), minimum(PVOutput), minimum(BatteryOutput), minimum(GeneratorOutput), minimum(PowerFromGrid)])

        start_values = []
        end_values = []
    
        PMD_TimeSteps_inREoptTime =  Microgrid_Inputs.PMD_time_steps

        for i in collect(1:length(PMD_TimeSteps_inREoptTime))
            if i == 1
                push!(start_values, PMD_TimeSteps_inREoptTime[i])
            elseif i == length(PMD_TimeSteps_inREoptTime)
                push!(end_values, PMD_TimeSteps_inREoptTime[i])
            elseif PMD_TimeSteps_inREoptTime[i+1] - PMD_TimeSteps_inREoptTime[i] > 1
                push!(start_values, PMD_TimeSteps_inREoptTime[i+1])
                push!(end_values, PMD_TimeSteps_inREoptTime[i])
            else
                # Do nothing
            end
        end

        for i in collect(1:length(start_values))
            start_temp = start_values[i] / (24* Microgrid_Inputs.time_steps_per_hour)
            end_temp = end_values[i] / (24* Microgrid_Inputs.time_steps_per_hour)
            
            if i == 1
                legend = true
            else
                legend = false
            end
            push!(traces, PlotlyJS.scatter(name = "PMD Timesteps", showlegend = legend, fill = "toself", 
                x = [start_temp,start_temp,end_temp,end_temp,start_temp],
                y = [min,max,max,min,min],
                mode = "lines",
                line = PlotlyJS.attr(width=0),
                fillcolor = "gray",
                opacity = 0.35
            ))
        end  
    end

    push!(traces, PlotlyJS.scatter(name = "Total load", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="black", dash="dot"),
        x = days,
        y = TotalLoad_series
    ))
    push!(traces, PlotlyJS.scatter(name = "Combined PV Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="green"),
        x = days,
        y = PVOutput
    ))
    push!(traces, PlotlyJS.scatter(name = "Combined Battery Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="blue"),
        x = days,
        y = BatteryOutput
    ))
    push!(traces, PlotlyJS.scatter(name = "Combined Generator Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="gray"),
        x = days,
        y = GeneratorOutput
    ))    
    push!(traces, PlotlyJS.scatter(name = "Power from Substation", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="orange"),
        x = days,
        y = PowerFromGrid
    ))  
    
    if (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/24
        OutageStop_Line = OutageStopTimeStep/24
        push!(traces, PlotlyJS.scatter(name = "Outage Start", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="red", dash="dot"),
            x = [OutageStart_Line, OutageStart_Line],
            y = [0,maximum(TotalLoad_series)]
        ))  
        push!(traces, PlotlyJS.scatter(name = "Outage End", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3, color="red", dash="dot"),
            x = [OutageStop_Line, OutageStop_Line],
            y = [0,maximum(TotalLoad_series)]
        ))  
    end

    p = PlotlyJS.plot(traces, layout)
    display(p)
    PlotlyJS.savefig(p, Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/CombinedResults_PowerOutput_interactiveplot.html")
end
 

# Function to check for errors in the data inputs for the model
function RunDataChecks(Microgrid_Inputs,  REopt_dictionary; ldf_inputs_dictionary="")

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

        if Microgrid_Inputs.model_type == "BasicLinear"
            if p.s.settings.time_steps_per_hour != Int(ldf_inputs_dictionary["T"]/8760)
                throw(@error("The number of time steps in the ldf_inputs_dictionary must correlate to the time_steps_per_hour in all REopt nodes"))
            end
            if string(p.s.site.node) ∉ keys(ldf_inputs_dictionary["load_nodes"]) #  ∉ is the "not in" symbol
                throw(@error("The REopt node $(node_temp) is not in the list of nodes in the ldf_inputs_dictionary"))
            end
        end

    end
    
    if Microgrid_Inputs.model_type == "BasicLinear"
        if ldf_inputs_dictionary["v0_input"] > ldf_inputs_dictionary["v_uplim_input"]
            throw(@error("In the ldf_inputs_dictionary, the v0_input value must be less than the v_uplim_input value"))
        end 
        if ldf_inputs_dictionary["v0_input"] < ldf_inputs_dictionary["v_lolim_input"]
            throw(@error("In the ldf_inputs_dictionary, the v0_input value must be greater than the v_lolim_input value"))
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