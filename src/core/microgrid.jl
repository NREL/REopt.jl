# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`microgrid` is an optional input with the following keys and default values:
```julia
    FolderLocation::String="",
    Bus_Coordinates::String="",  # Location of the csv document with the bus coordinates
    PMD_network_input::String="",
    MicrogridType::String="BehindTheMeter",  # Options: "BehindTheMeter", "CommunityDistrict", or "Offgrid"
    Nonlinear_Solver::Bool=false,
    Model_Type::String="BasicLinear",  #Options: "BasicLinear", "PowerModelsDistribution"
    REoptInputsList::Array=[], 
    FacilityMeter_Node::String="",
    Substation_Node::String="",
    SubstationLine::String="",
    AllowExportBeyondSubstation::Bool=false,
    SubstationExportLimit::Real=0,
    SubstationImportLimit::Real=0,
    Model_Switches::Bool=false,
    Model_Line_Upgrades::Bool=false,
    Line_Upgrade_Options::Dict=Dict(), 
    Model_Transformer_Upgrades::Bool=false,
    Transformer_Upgrade_Options::Dict=Dict(),
    Switch_Open_Timesteps::Dict=Dict(),
    SingleOutageStartTimeStep::Real=0,
    SingleOutageStopTimeStep::Real=0,
    RunOutageSimulator::Bool=false,
    LengthOfOutages_timesteps::Array=[],
    Critical_Load_Method::String="Fraction",
    Critical_Load_Fraction::Real=0.0,
    Critical_Load_TimeSeries::Array=[],
    NumberOfOutagesToEvaluate::Real=0,
    RunNumbersForPlottingOutageSimulatorResults::Array=[], 
    TimeStepsPerHour::Real=0,
    GeneratorFuelGallonAvailable::Dict=Dict(),
    Generate_CSV_of_outputs::Bool=false,
    Generate_Results_Plots::Bool=false,
    ResultPlotsStartTimeStep::Real=0,
    ResultPlotsEndTimeStep::Real=0,
    PlotVoltageDrop::Bool=true,
    PlotVoltageDrop_NodeNumbers::Array=[],
    PlotVoltageDrop_VoltageTimeStep::Real=0,
    Display_Results::Bool=true

"""

mutable struct MicrogridInputs <: AbstractMicrogrid
    FolderLocation
    Bus_Coordinates
    PMD_network_input
    MicrogridType
    Model_Type
    Nonlinear_Solver
    REoptInputsList
    FacilityMeter_Node
    Substation_Node
    SubstationLine
    AllowExportBeyondSubstation
    SubstationExportLimit
    SubstationImportLimit
    Model_Switches
    Model_Line_Upgrades
    Line_Upgrade_Options 
    Model_Transformer_Upgrades
    Transformer_Upgrade_Options
    Switch_Open_Timesteps
    SingleOutageStartTimeStep
    SingleOutageStopTimeStep
    RunOutageSimulator
    LengthOfOutages_timesteps
    Critical_Load_Method
    Critical_Load_Fraction
    Critical_Load_TimeSeries
    NumberOfOutagesToEvaluate
    RunNumbersForPlottingOutageSimulatorResults
    TimeStepsPerHour
    GeneratorFuelGallonAvailable
    Generate_CSV_of_outputs
    Generate_Results_Plots
    ResultPlotsStartTimeStep
    ResultPlotsEndTimeStep
    PlotVoltageDrop
    PlotVoltageDrop_NodeNumbers
    PlotVoltageDrop_VoltageTimeStep
    Display_Results
    load_profiles_for_outage_sim_if_using_the_fraction_method

    function MicrogridInputs(;
        FolderLocation::String="",
        Bus_Coordinates::String="",  # Location of the csv document with the bus coordinates
        PMD_network_input::String="",
        MicrogridType::String="BehindTheMeter",  # Options: "BehindTheMeter", "CommunityDistrict", or "Offgrid"
        Model_Type::String="BasicLinear",  #Options: "BasicLinear", "PowerModelsDistribution"
        Nonlinear_Solver::Bool=false,
        REoptInputsList::Array=[], 
        FacilityMeter_Node::String="",
        Substation_Node::String="",
        SubstationLine::String="",
        AllowExportBeyondSubstation::Bool=false,
        SubstationExportLimit::Real=0,
        SubstationImportLimit::Real=0,
        Model_Switches::Bool=false,
        Model_Line_Upgrades::Bool=false,
        Line_Upgrade_Options::Dict=Dict(), 
        Model_Transformer_Upgrades::Bool=false,
        Transformer_Upgrade_Options::Dict=Dict(),
        Switch_Open_Timesteps::Dict=Dict(),
        SingleOutageStartTimeStep::Real=0,
        SingleOutageStopTimeStep::Real=0,
        RunOutageSimulator::Bool=false,
        LengthOfOutages_timesteps::Array=[],
        Critical_Load_Method::String="Fraction",
        Critical_Load_Fraction::Dict=Dict(),
        Critical_Load_TimeSeries::Dict=Dict(),
        NumberOfOutagesToEvaluate::Real=0,
        RunNumbersForPlottingOutageSimulatorResults::Array=[], 
        TimeStepsPerHour::Real=0,
        GeneratorFuelGallonAvailable::Dict=Dict(),
        Generate_CSV_of_outputs::Bool=false,
        Generate_Results_Plots::Bool=false,
        ResultPlotsStartTimeStep::Real=0,
        ResultPlotsEndTimeStep::Real=0,
        PlotVoltageDrop::Bool=true,
        PlotVoltageDrop_NodeNumbers::Array=[],
        PlotVoltageDrop_VoltageTimeStep::Real=0,
        Display_Results::Bool=true,
        load_profiles_for_outage_sim_if_using_the_fraction_method::Array=[]
        
        )
    
    new(
        FolderLocation,
        Bus_Coordinates,
        PMD_network_input,
        MicrogridType,
        Model_Type,  
        Nonlinear_Solver,
        REoptInputsList,
        FacilityMeter_Node,
        Substation_Node,
        SubstationLine,
        AllowExportBeyondSubstation,
        SubstationExportLimit,
        SubstationImportLimit,
        Model_Switches,
        Model_Line_Upgrades,
        Line_Upgrade_Options, 
        Model_Transformer_Upgrades,
        Transformer_Upgrade_Options,
        Switch_Open_Timesteps,
        SingleOutageStartTimeStep,
        SingleOutageStopTimeStep,
        RunOutageSimulator,
        LengthOfOutages_timesteps,
        Critical_Load_Method,
        Critical_Load_Fraction,
        Critical_Load_TimeSeries,
        NumberOfOutagesToEvaluate,
        RunNumbersForPlottingOutageSimulatorResults,
        TimeStepsPerHour,
        GeneratorFuelGallonAvailable,
        Generate_CSV_of_outputs,
        Generate_Results_Plots,
        ResultPlotsStartTimeStep,
        ResultPlotsEndTimeStep,
        PlotVoltageDrop,
        PlotVoltageDrop_NodeNumbers,
        PlotVoltageDrop_VoltageTimeStep,
        Display_Results,
        load_profiles_for_outage_sim_if_using_the_fraction_method
    )
   
    end
end
const PMD = PowerModelsDistribution

# The main function to run all parts of the model
function Microgrid_Model(Microgrid_Inputs; JuMP_Model="", ldf_inputs_dictionary="")
    
    StartTime_EntireModel = now() # Record the start time for the computation
    Microgrid_Settings = REopt.MicrogridInputs(; REopt.dictkeys_tosymbols(Microgrid_Inputs)...)
    cd(Microgrid_Settings.FolderLocation)

    # Create a folder for the outputs if saving results
    TimeStamp = Dates.format(now(), "mm-dd-yyyy")*"_"*Dates.format(now(), "HH-MM")
    if Microgrid_Settings.Generate_CSV_of_outputs == true || Microgrid_Settings.Generate_Results_Plots == true
        @info "Creating a folder for the results"
        mkdir(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp)
    end
    if Microgrid_Settings.Generate_Results_Plots == true
        mkdir(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots") 
    end
    
    # Prepare the electric loads
    REopt_inputs_all_nodes = Microgrid_Settings.REoptInputsList

    # Prepare loads for using with the outage simulator, if the fraction method is used for determining the critical load
    if  Microgrid_Settings.Critical_Load_Method == "Fraction"
        load_profiles_for_outage_sim_if_using_the_fraction_method = Dict([])
        for REopt_inputs in REopt_inputs_all_nodes
            load_profiles_for_outage_sim_if_using_the_fraction_method[REopt_inputs["Site"]["node"]] = deepcopy( REopt_inputs["ElectricLoad"]["loads_kw"] )
        end
        Microgrid_Settings.load_profiles_for_outage_sim_if_using_the_fraction_method = load_profiles_for_outage_sim_if_using_the_fraction_method
    else
        Microgrid_Settings.load_profiles_for_outage_sim_if_using_the_fraction_method = ""
    end
    
    # If outages are defined in the optimization, set the loads to the critical loads during the outages
    if Microgrid_Settings.SingleOutageStopTimeStep - Microgrid_Settings.SingleOutageStartTimeStep > 0
        
        OutageStart = Microgrid_Settings.SingleOutageStartTimeStep
        OutageEnd = Microgrid_Settings.SingleOutageStopTimeStep

        for i in 1:length(Microgrid_Settings.REoptInputsList)
            
            node = Microgrid_Settings.REoptInputsList[i]["Site"]["node"]

            if Microgrid_Settings.Critical_Load_Method == "Fraction"
                if sum(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"]) > 0 # only apply the critical load fraction if there is a load on the node
                    load_segment_initial = deepcopy(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = 0.75 * load_segment_initial[OutageStart:OutageEnd]                    
                    delete!(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"],"loads_kw")
                    Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end 
            elseif Microgrid_Settings.Critical_Load_Method == "TimeSeries"
                if sum(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"]) > 0 
                    load_segment_initial = deepcopy(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = Microgrid_Settings.Critical_Load_TimeSeries[string(node)][OutageStart:OutageEnd]                    
                    delete!(Microgrid_Settings.REoptInputsList[i]["ElectricLoad"],"loads_kw")
                    Microgrid_Settings.REoptInputsList[i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end
            end
        end
    end     
    
    # Generate the scenarios, REoptInputs, and list of REoptInputs
    scenarios = Dict([])
    for i in 1:length(Microgrid_Settings.REoptInputsList)
        scenarios[i] = Scenario(Microgrid_Settings.REoptInputsList[i])
    end

    REoptInputs_dictionary = Dict([])
    for i in 1:length(Microgrid_Settings.REoptInputsList)
        REoptInputs_dictionary[i] = REoptInputs(scenarios[i])
    end

    REopt_dictionary = [REoptInputs_dictionary[1]]
    for i in 2:length(Microgrid_Settings.REoptInputsList)
        push!(REopt_dictionary, REoptInputs_dictionary[i])
    end
    
    if Microgrid_Settings.Model_Type == "PowerModelsDistribution"
        
        
        # Run function to check for errors in the model inputs
        RunDataChecks(Microgrid_Settings, REopt_dictionary)
        
        m, pm, data_math_mn = Create_PMD_Model_For_REopt_Integration(Microgrid_Settings)
        
        results, LineInfo_PMD, data_math_mn, REoptInputs_Combined, m = Build_REopt_and_Link_To_PMD(m, pm, Microgrid_Settings, data_math_mn)

        REopt_Results, PMD_Results, DataDictionaryForEachNode = Results_Processing_REopt_PMD_Model(m, results, data_math_mn, REoptInputs_Combined, Microgrid_Settings)
            
        if Microgrid_Settings.RunOutageSimulator == true
            OutageLengths = Microgrid_Settings.LengthOfOutages_timesteps 
            TimeStepsPerHour = Microgrid_Settings.TimeStepsPerHour 
            NumberOfOutagesToTest = Microgrid_Settings.NumberOfOutagesToEvaluate

            # When line and transformer upgrades are implemented into the REopt-PMD model, define these inputs for the outage simulator
            line_max_amps = "N/A"
            lines_rmatrix= "N/A"
            lines_xmatrix= "N/A"
            lines_for_upgrades= "N/A"
            line_upgrades_each_line= "N/A"
            all_lines= "N/A"
            transformer_max_kva= "N/A"
            
            Outage_Results = Dict([])
            for i in 1:length(OutageLengths)
                OutageLength = OutageLengths[i]
                OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived = Microgrid_OutageSimulator(DataDictionaryForEachNode, 
                                                                                                                            REopt_dictionary, 
                                                                                                                            Microgrid_Settings, 
                                                                                                                            TimeStamp;
                                                                                                                            LineInfo_PMD = LineInfo_PMD, 
                                                                                                                            NumberOfOutagesToTest = NumberOfOutagesToTest, 
                                                                                                                            OutageLength_TimeSteps_Input = OutageLength)
                Outage_Results["$(OutageLength_TimeSteps)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, "NumberOfRuns" => RunNumber, "NumberOfOutagesSurvived" => SuccessfullySolved ])
            end 
        else
            print("\n  Not running the microgrid outage simulator in this model")
            Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
        end 

        EndTime_EntireModel = now()
        ComputationTime_EntireModel = EndTime_EntireModel - StartTime_EntireModel

        #Results Compilation function
        DataFrame_LineFlow_Summary = "TBD"
        Dictionary_LineFlow_Power_Series = "TBD"
        system_results = REopt.Results_Compilation(REopt_Results, Outage_Results, Microgrid_Settings, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel)

            
        # Compile output data into a dictionary to return from the dictionary
        CompiledResults = Dict([("System_Results", system_results),
                                ("DataDictionaryForEachNode", DataDictionaryForEachNode), 
                                #("FromREopt_Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                                #("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series), 
                                ("PMD_results", PMD_Results),
                                ("REopt_results", REopt_Results),
                                ("Outage_Results", Outage_Results),
                                #("DataFrame_LineFlow_Summary", DataFrame_LineFlow_Summary),
                                ("ComputationTime_EntireModel", ComputationTime_EntireModel),
                                #("line_upgrade_options", line_upgrade_options_output),
                                #("transformer_upgrade_options", transformer_upgrade_options_output),
                                #("line_upgrade_results", line_upgrade_results_output),
                                #("transformer_upgrade_results", transformer_upgrade_results_output)
                                ])

    elseif Microgrid_Settings.Model_Type == "BasicLinear"
        # Run function to check for errors in the model inputs
        RunDataChecks(Microgrid_Settings, REopt_dictionary; ldf_inputs_dictionary = ldf_inputs_dictionary)
            
        # Run the optimization:
        DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results, DataFrame_LineFlow_Summary, LineNominalVoltages_Summary, BusNominalVoltages_Summary, model, lines_for_upgrades, line_upgrade_options, transformer_upgrade_options, line_upgrade_results, transformer_upgrade_results, line_upgrades_each_line, all_lines = Microgrid_REopt_Model_BasicLinear(JuMP_Model, Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary, TimeStamp) # ps_B, TimeStamp) #
        
        # Run the outage simulator if "RunOutageSimulator" is set to true
        if Microgrid_Settings.RunOutageSimulator == true
            OutageLengths = Microgrid_Settings.LengthOfOutages_timesteps 
            TimeStepsPerHour = Microgrid_Settings.TimeStepsPerHour 
            NumberOfOutagesToTest = Microgrid_Settings.NumberOfOutagesToEvaluate

            line_max_amps = value.(model[:line_max_amps])
            if Microgrid_Settings.Model_Line_Upgrades == true && Microgrid_Settings.Nonlinear_Solver == true
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
                OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived = Microgrid_OutageSimulator(DataDictionaryForEachNode, 
                                                                                                                            REopt_dictionary, 
                                                                                                                            Microgrid_Settings,  
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
            print("\n  Not running the microgrid outage simulator in this model")
            Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
        end 

        EndTime_EntireModel = now()
        ComputationTime_EntireModel = EndTime_EntireModel - StartTime_EntireModel
        # Results processing and generation of outputs:
        system_results = Results_Compilation(results, Outage_Results, Microgrid_Settings, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; line_upgrade_results=dataframe_line_upgrade_summary, transformer_upgrade_results=dataframe_transformer_upgrade_summary)
    
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

    if Microgrid_Settings.Generate_Results_Plots == true
        # Note: PlotlyJS is required to run these functions, and PlotlyJS must be in the local development environment.
        CreateResultsMap(CompiledResults, Microgrid_Settings, TimeStamp)
        Aggregated_PowerFlows_Plot(CompiledResults, TimeStamp, Microgrid_Settings)
    end

    return CompiledResults, model  
end


function Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs)
    # Load in the data from the OpenDSS inputs file; data is stored to the data_eng variable
    print("\n Parsing the network input file")
    data_eng = PowerModelsDistribution.parse_file(Microgrid_Inputs.FolderLocation.*"/"*Microgrid_Inputs.PMD_network_input)
    # Generate a list of the REopt nodes
    REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs)
    
    # General notes about PMD: 
        # data_eng stores all of the inputs for the PMD model
        # Within data_eng, there are lots of other inputs that can be adjust and modified, such as the sbase of the model
        # Two data models in PMD: "Engineering" and "Mathematical" - Engineering uses SI units, Mathematical uses per unit units
        # TODO: what are the "conductor_ids" refering to in the data_eng dictionary?
        # To view the variables in the model, type:  pm.var[:it][:pmd][:nw][1]  # This shows the variables in time step 1
    
    #PMD.reduce_lines!(data_eng) # use this to reduce the network to get a similar and "sometimes equivalent" result "when linecharging is negligible" - I think this function combines some lines together to make the optimization problem smaller, but these concepts are unfamiliar to me and I'm confused by this explanation in the PMD documentation
    
    print("\n Defining several settings in the data_eng dictionary:")
    
    # From the PMD extension tutorial: "Since the optimization model is generated from the 'Mathematical' model, specify explicitly what the power base should be. Set it to 1 kW, so the unit is the same as in" the model we are pairing PMD to    
        data_eng["settings"]["sbase_default"] = 1.0*1E3/data_eng["settings"]["power_scale_factor"] # This sets the power base (sbase) equal to 1 kW:
    
    data_eng["voltage_source"]["source"]["bus"] = "sourcebus" # Define the location of the source bus in the network
    data_eng["settings"]["name"] = "test_case" # Define other parameters too:
    
    # From PMD extension tutorial: "We require that in per unit, the phase voltage magnitude and neutral magnitude should obey:" 
        # neutral voltage magnitude <= 1
        #  0.9 <= phase voltage magnitude <= 1.1
        # Add these constraints using:
    
    print("\n Adding per unit voltage bounds to the buses")
    PMD.add_bus_absolute_vbounds!(
        data_eng,
        phase_lb_pu=0.9,
        phase_ub_pu=1.1,
        neutral_ub_pu=0.1
    )
    
    # First, apply a timeseries load profile to the PMD model
        # see line 272 in the PMD extension tutorial code
        # Note: unclear if this needs to be done because loads will be modeled separately from PMD
    
    print("\n Defining a time series load profile")
    TotalPMDTimeSteps = 4000
    begin
        data_eng["time_series"] = Dict{String,Any}()
        data_eng["time_series"]["normalized_load_profile"] = Dict{String,Any}(
                "replace" => false,
                "time" => 1:TotalPMDTimeSteps,
                "values" => zeros(TotalPMDTimeSteps)
        )
        for i in REopt_nodes
            if string(i) != Microgrid_Inputs.FacilityMeter_Node  # Don't assign loads to the facility meter
                data_eng["load"]["load$(i)"]["time_series"] = Dict(
                        "pd_nom"=>"normalized_load_profile",
                        "qd_nom"=> "normalized_load_profile"
                )
            end
        end
    end
    
    # From the PMD extension tutorial: "need to add a generator for each EV, and specify the connection settings. In the test case we imported, LVTestCase, each load represents a household with a single-phase connection. We now associate each EV with a household, and give it the same bus and phase connection." 
        # In summary: the OpenDSS inputs file should indicate the location of the loads
    
    # Add generators to the model as a generic interface with the REopt model:
    print("\n Adding a generic PMD generator for each of the REopt nodes, in order to be able to connect the REopt and PMD models")
    begin
        # I think this needs to be adjust for three phase loads (mainly in the "connections" field and/or "configuration" field)
        data_eng["generator"] = Dict{String, Any}()
        for e in REopt_nodes
            if string(e) != Microgrid_Inputs.FacilityMeter_Node # Don't assign a generator interface to the facility meter
            data_eng["generator"]["REopt_gen_$e"] = Dict{String,Any}(
                        "status" => ENABLED,
                        "bus" => data_eng["load"]["load$(e)"]["bus"],   # previously was: bus_e[e], 
                        "connections" => [data_eng["load"]["load$(e)"]["connections"][1], 4], # [phase_e[e], 4],  # Note: From PMD tutorial: "create a generator with the same connection setting."
                        "configuration" => WYE,
            )
            end
        end
    end
    
    begin 
    # From PMD extension tutorial: "Transform the 'engineering' data model to a 'mathematical' model, and don't forget the 'multinetwork=true' flag."
        # I think the multinetwork setting is for time series optimizations
    print("\n Transforming the engineering model to a mathematical model in PMD \n")    
    data_math_mn = transform_data_model(data_eng, multinetwork=true)
    
    print("\n Initializing the voltage variables")
    # From PMD extension tutorial: Before solving the problem, it is important to add initialization values for the voltage variables. Failing to do so will almost always result in solver issues." 
    Start_vrvi = now()
    add_start_vrvi!(data_math_mn)
    End_vrvi = now()
    
    PMD_vrvi_time = End_vrvi - Start_vrvi
    PMD_vrvi_time_minutes = round(PMD_vrvi_time/Millisecond(60000), digits=2)
    print("\n The PMD_vrvi_time was: $(PMD_vrvi_time_minutes) minutes")
    
    # Build the optimization model:
        # Note: Based on the PMD documentation, instantiate_mc_model automatically converts the "engineering" model into a "mathematical" model
    print("\n Instantiating the PMD model (this may take a few minutes for large models)")
    Start_instantiate = now()
    pm = instantiate_mc_model(data_math_mn, LPUBFDiagPowerModel, build_mn_mc_opf)  # the second input is the optimization class; the third I think is the method. mn_mc_opf is for multinetwork optimal power flow
    End_instantiate = now()
    print("\n Completed instantiation of the PMD model")
    
    PMD_instantiate_time = End_instantiate - Start_instantiate
    PMD_instantiate_time_minutes = round(PMD_instantiate_time/Millisecond(60000), digits=2)
    print("\n The PMD_instantiate_time was: $(PMD_instantiate_time_minutes) minutes")
    
    end 
    
    # Extract the JuMP model
    m = pm.model;
    
    return m, pm, data_math_mn
end



function Build_REopt_and_Link_To_PMD(m, pm, Microgrid_Inputs, data_math_mn)
    # Generate REoptInputs for each of the REopt nodes
    REoptInputsList = Microgrid_Inputs.REoptInputsList 
    REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs)
    
    scenarios = Dict([])
    for i in 1:length(REoptInputsList)
        scenarios[i] = Scenario(REoptInputsList[i])
        print("\n Creating Scenario $(i)")
    end
    
    REoptInputs_dictionary = Dict([])
    for i in 1:length(REoptInputsList)
        REoptInputs_dictionary[i] = REoptInputs(scenarios[i])
        print("\n Creating REopt Input $(i)")
    end
    
    REoptInputs_Combined = [REoptInputs_dictionary[1]]
    for i in 2:length(REoptInputsList)
        push!(REoptInputs_Combined, REoptInputs_dictionary[i])
    end
    
    # The next step is to make the connection between the REopt model and the PMD model
    # Pass the PMD JuMP model (with the PowerModelsDistribution variables and constraints) to REopt
    print("\n Building the REopt model\n")
    REopt.build_reopt!(m, REoptInputs_Combined)
    
    # Connect the PMD and REopt models
        # Note: the expression  REoptInputs_Combined[1].s.site.node  yields 2
    
    for p in REoptInputs_Combined
        _n = string("_", p.s.site.node)
        if string(p.s.site.node) != p.s.settings.facilitymeter_node
            print("\n Applying total export equation for node $(p.s.site.node)")
            m[Symbol("TotalExport"*_n)] = @expression(m, [ts in p.time_steps],
                sum(
                    m[Symbol("dvProductionToGrid"*_n)][t,u,ts] 
                    for t in p.techs.elec, u in p.export_bins_by_tech[t]
                )
                + sum(m[Symbol("dvStorageToGrid"*_n)][b,ts] for b in p.s.storage.types.all )# added this line to include battery export in the total export
            )
        else
            # set the total node export to 0 for the facility meter grid, because that node has no techs
            # also, for that node, the dvProductionToGrid is used for the grid export benefits and set to the powerflow of the substation line when flow on that line is negative
            print("\n Not creating a total export variable for node $(p.s.site.node) because this node is the facility meter node.")
        end
    end
    
    # Connect the PMD and REopt variables through constraints
    
    gen_name2ind = Dict(gen["name"] => gen["index"] for (_,gen) in data_math_mn["nw"]["1"]["gen"]);
    
    REopt_gen_ind_e = [gen_name2ind["REopt_gen_$e"] for e in REopt_nodes];
    
    TotalPMDTimeSteps = 4000
    TimeSteps = 1:TotalPMDTimeSteps
    begin 
        PMD_Pg_ek = [PMD.var(pm, k, :pg, e).data[1] for e in REopt_gen_ind_e, k in TimeSteps ] # Previously was: PMD_Pg_ek = [PMD.var(pm, k, :pg, REopt_gen_ind_e[e]).data[1] for e in REopt_nodes, k in TimeSteps ]
        PMD_Qg_ek = [PMD.var(pm, k, :qg, e).data[1] for e in REopt_gen_ind_e, k in TimeSteps]
    end
    
    buses = REopt_nodes
    
    for e in REopt_gen_ind_e  #Note: the REopt_gen_ind_e does not contain the facility meter
        JuMP.@constraint(m, [k in TimeSteps],  # Previously was: [e in REopt_gen_ind_e, k in TimeSteps], and before that was [e in REopt_nodes, k in TimeSteps],
                            PMD_Pg_ek[e,k] == m[Symbol("TotalExport_"*string(buses[e]))][k]  - m[Symbol("dvGridPurchase_"*string(buses[e]))][k]   # negative power "generation" is a load
        )
        # TODO: add reactive power to the REopt nodes
        JuMP.@constraint(m, [k in TimeSteps],
                            PMD_Qg_ek[e,k] == 0.0 #m[Symbol("TotalExport_"*string(buses[e]))][k]  - m[Symbol("dvGridPurchase_"*string(buses[e]))][k] 
        )
    end
    
    # Create constraints to turn off power flow at various locations and times
        # Notes:
            # PMD gives all of the lines a new ID, which is just an integer.
            # The line below lists off the parameters stored for line ID 2
            #data_lineID2 = PMD.ref(pm, 1, :branch, 2) # This shows the f_bus and t_bus, which, along with the line ID (2), is used as an index in the :p decision variable 
    
            #PMD.ref(pm, 1, :branch, 2)["name"]  # This correlates with the name provided in the OpenDSS inputs files
            #PMD.ref(pm, 1, :branch, 2)["t_bus"]
            #PMD.ref(pm, 1, :branch, 2)["f_bus"]
                # note, there is a "rate_a" field which may be able to be used to model line upgrades
    
    # Create a dictionary with the line names and corresponding indeces for the :p decision variable
    LineInfo = Dict([])
    
    NumberOfBranches = 20  # TODO: auto compute the number of branches
    for i in 1:NumberOfBranches
        LineData = PMD.ref(pm, 1, :branch, i)
        LineInfo[LineData["name"]] = Dict(["index"=>LineData["index"], "t_bus"=>LineData["t_bus"], "f_bus"=>LineData["f_bus"]])
    end
    
    
    # Restrict power flow from the substation if the microgrid type is offgrid
    if Microgrid_Inputs.MicrogridType == "Offgrid"
        RestrictLinePowerFlow(pm, Microgrid_Inputs.SubstationLine, collect(1:TotalPMDTimeSteps), LineInfo; Off_Grid=true)
    end
    
    # Define limits on grid import and export
    if Microgrid_Inputs.AllowExportBeyondSubstation == false # Prevent power from being exported to the grid beyond the facility meter:
        print("\n Prohibiting power export at the substation")
        RestrictLinePowerFlow(pm, m, Microgrid_Inputs.SubstationLine, collect(1:TotalPMDTimeSteps), LineInfo; Prevent_Export=true)
    elseif Microgrid_Inputs.SubstationExportLimit != ""
        print("\n Applying a limit to the power export at the substation")
        RestrictLinePowerFlow(pm, m, Microgrid_Inputs.SubstationLine, collect(1:TotalPMDTimeSteps), LineInfo; Substation_Export_Limit = Microgrid_Inputs.SubstationExportLimit)
    end 
    
    if Microgrid_Inputs.SubstationImportLimit != ""
        print("\n Applying a limit to the power import from the substation")
        RestrictLinePowerFlow(pm, m, Microgrid_Inputs.SubstationLine, collect(1:TotalPMDTimeSteps), LineInfo; Substation_Import_Limit = Microgrid_Inputs.SubstationImportLimit)
    end 
    
    # Apply a grid outage to the model
    if Microgrid_Inputs.SingleOutageStopTimeStep - Microgrid_Inputs.SingleOutageStartTimeStep > 0
        print("\n Applying a grid outage from time step $(Microgrid_Inputs.SingleOutageStartTimeStep) to $(Microgrid_Inputs.SingleOutageStopTimeStep) ")
        RestrictLinePowerFlow(pm, m, Microgrid_Inputs.SubstationLine, collect(Microgrid_Inputs.SingleOutageStartTimeStep:Microgrid_Inputs.SingleOutageStopTimeStep), LineInfo; Single_Outage=true)
    end
    
    # Open switches if defined by the user
        # Note: the switch capability in PMD is not used currently in this model, but the switch openings are modeling with these constraints
            # For reference, this is an example input into the REopt_Inputs dictionary's "Switch_Open_Timesteps" field
            #Switch_Open_Timesteps = Dict([
            #    ("15-11", collect(2500:2900)) # the time steps that the switch is open
            #])
    
    if Microgrid_Inputs.Switch_Open_Timesteps != ""
        print("\n Switches modeled:")
        for i in keys(Microgrid_Inputs.Switch_Open_Timesteps)
            print("\n   Opening the switch on line $(i) from timesteps $(minimum(Microgrid_Inputs.Switch_Open_Timesteps[i])) to $(maximum(Microgrid_Inputs.Switch_Open_Timesteps[i])) \n")
            RestrictLinePowerFlow(pm, m, "line"*i, Microgrid_Inputs.Switch_Open_Timesteps[i], LineInfo; Switches_Open=true)
        end
    end
    
    # Link export through the substation to the utility tariff on the facility meter node
    
    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            @info "Setting facility-level grid purchase and export (if applicable) to the power flow on line "*string(Microgrid_Inputs.SubstationLine)*", using the variable: "*string(" dvGridPurchase_", p.s.settings.facilitymeter_node)
            @info "The export bins for the facility meter node are: $(p.export_bins_by_tech["PV"])"
            
            i = LineInfo[Microgrid_Inputs.SubstationLine]["index"]
            # Based off of code in line 470 of PMD's src>core>constraint_template
            timestep = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
            branch = ref(pm, timestep, :branch, i)
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            f_connections = branch["f_connections"]
            t_connections = branch["t_connections"]
            f_idx = (i, f_bus, t_bus)
            t_idx = (i, t_bus, f_bus)
    
            @variable(m, binSubstationPositivePowerFlow[ts in p.time_steps], Bin)
            for t in collect(length(TimeSteps):length(p.time_steps))
                @constraint(m, m[:binSubstationPositivePowerFlow][t] == 1) # Temporary constraint; delete this when use 8760 data with PMD
            end
    
            for timestep in TimeSteps
                # Based off of code in line 274 of PMD's src>core>constraints
                    p_fr = [PMD.var(pm, timestep, :p, f_idx)[c] for c in f_connections]
                    p_to = [PMD.var(pm, timestep, :p, t_idx)[c] for c in t_connections]
            
                    q_fr = [PMD.var(pm, timestep, :q, f_idx)[c] for c in f_connections]
                    q_to = [PMD.var(pm, timestep, :q, t_idx)[c] for c in t_connections]
            
                if Microgrid_Inputs.AllowExportBeyondSubstation == true
                    #@info "Allowing export from the facility meter, which is limited to the defined export limit"
                
                    @constraint(m, m[:binSubstationPositivePowerFlow][timestep] => {p_fr[1] >= 0 } )  # TODO: make this compatible with three phase (right now it's only consider 1-phase I think)
                    @constraint(m, !m[:binSubstationPositivePowerFlow][timestep] => {p_fr[1] <= 0 } )
                
                    # Set the power flowing through the line from the substation to be the grid purchase minus the dvProductionToGrid for node 15
                    #TODO: make this compatible with three phase power- I believe p_fr[1] only refers to the first phase
                    @constraint(m, 
                        (p_fr[1] == sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]))) 
                    
                    @constraint(m,
                        sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) <= Microgrid_Inputs.SubstationImportLimit * binSubstationPositivePowerFlow[timestep])
                    
                    @constraint(m,
                        sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]) <= Microgrid_Inputs.SubstationExportLimit * (1 - binSubstationPositivePowerFlow[timestep]))
                            
                else
                    @info "Not allowing export from the facility meter"
    
                    @constraint(m, 
                        sum(m[Symbol("dvGridPurchase_"*p.s.settings.facilitymeter_node)][timestep, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) == p_fr)
                    
                    @constraint(m, 
                        sum(m[Symbol("dvProductionToGrid_"*p.s.settings.facilitymeter_node)]["PV", u, timestep] for u in p.export_bins_by_tech["PV"]) == 0)
                end
            end
        end
    end
    
    # Define the optimization objective
    print("\n Adding an objective to the optimization model")
    @expression(m, Costs, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in REoptInputs_Combined) );
    
    @objective(m, Min, m[:Costs]);
    
    # The optimize_model! function is a wrapper from PMD and it includes some organization of the results
        # unclear if it is compatible with the REopt results
    set_optimizer(m, Xpress.Optimizer)
    set_optimizer_attribute(m, "MIPRELSTOP", 0.05)
    
    print("\n The optimization is starting\n")
    results = PMD.optimize_model!(pm) #  Option other fields: relax_intregrality=true, optimizer=Xpress.Optimizer) # The default in PMD for relax_integrality is false
    print("\n The optimization is complete\n")
    
    TerminationStatus = string(results["termination_status"])
    if TerminationStatus != "OPTIMAL"
        throw(@error("The termination status of the optimization was"*string(results["termination_status"])))
    end
    
    # Save the PMD model type to a variable
    PMD_ModelType = typeof(pm)
    
    return results, LineInfo, data_math_mn, REoptInputs_Combined, m
end


function RestrictLinePowerFlow(pm, m, line, timesteps, LineInfo; Single_Outage=false, Off_Grid=false, Switches_Open=false, Prevent_Export=false, Substation_Export_Limit="", Substation_Import_Limit="")
    # Function used for restricting power flow for grid outages, times when switches are opened, and substation import and export limits
        
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

    for timestep in timesteps
        # Based off of code in line 274 of PMD's src>core>constraints
        p_fr = [PMD.var(pm, timestep, :p, f_idx)[c] for c in f_connections]
        p_to = [PMD.var(pm, timestep, :p, t_idx)[c] for c in t_connections]

        q_fr = [PMD.var(pm, timestep, :q, f_idx)[c] for c in f_connections]
        q_to = [PMD.var(pm, timestep, :q, t_idx)[c] for c in t_connections]
        
        if Prevent_Export == true
            @info("Preventing all export to the grid")
            JuMP.@constraint(m, p_fr .>= 0) 
            JuMP.@constraint(m, q_fr .>= 0)
        end

        if Substation_Export_Limit != ""
            # Set a substation export limit
            #@info("Applying an export limit from the substation of $(Substation_Export_Limit)")
            JuMP.@constraint(m, p_fr .>= -Substation_Export_Limit) # TODO: change this to deal with multi-phase power correctly: likely need to sum p_to across each of the connections
            JuMP.@constraint(m, q_fr .>= -Substation_Export_Limit) # TODO apply power factor to the export limit for Q
        end
        if Substation_Import_Limit != ""
            # Set a substation import limit
            #@info("Applying an import limit from the substation of $(Substation_Import_Limit)")
            JuMP.@constraint(m, p_fr .<= Substation_Import_Limit)
            JuMP.@constraint(m, q_fr .<= Substation_Import_Limit) # TODO apply power factor to the import limit for Q
        end
        if Off_Grid == true || Single_Outage == true || Switches_Open==true
            # Restrict all power flow
            JuMP.@constraint(m, p_fr .== 0)  # The _fr and _to variables are just indicating power flow in either direction on the line. In PMD, there is a constraint that requires  p_to = -p_fr 
            JuMP.@constraint(m, p_to .== 0)  # TODO test removing the "fr" constraints here in order to reduce the # of constraints in the model
            JuMP.@constraint(m, q_fr .== 0)
            JuMP.@constraint(m, q_to .== 0)
        end
    end
end


function Results_Processing_REopt_PMD_Model(m, results, data_math_mn, REoptInputs_Combined, Microgrid_Settings)
    # Extract the PMD results
    print("\n Reading the PMD results")
    sol_math = results["solution"]
    # The PMD results are saved to the sol_eng variable
    sol_eng = transform_solution(sol_math, data_math_mn)

    # Extract the REopt results
    print("\n Reading the REopt results")
    REopt_results = reopt_results(m, REoptInputs_Combined)

    DataDictionaryForEachNodeForOutageSimulator = REopt.GenerateInputsForOutageSimulator(Microgrid_Settings, REopt_results)
    return REopt_results, sol_eng, DataDictionaryForEachNodeForOutageSimulator
end 


function Check_REopt_PMD_Alignment()
    # Compare the REopt and PMD results to ensure the models are linked
        # Note the calculations below are only valid if there are not any REopt nodes or PMD loads downstream of the node being evaluated

    Node = 2 # This is for the REopt data
    Line = "line1_2" # This is for the PMD data
    Phase = 1  # This data is for the PMD data

    # Save REopt data to variables for comparison with PMD:
    TotalExport = JuMP.value.(m[Symbol("TotalExport_"*string(Node))]) #[1]
    TotalImport = JuMP.value.(m[Symbol("dvGridPurchase_"*string(Node))]) #[1] If needed, define the time step in the brackets appended to this line

    GridImport_REopt = REopt_results[Node]["ElectricUtility"]["electric_to_storage_series_kw"] + REopt_results[Node]["ElectricUtility"]["electric_to_load_series_kw"] 

    REopt_power_injection = TotalImport - TotalExport

    # Save the power injection data from PMD into a vector for line12_1
        # Note, when using the expression: TimeStep1_line = sol_eng["nw"]["1"]["line"][Line] # There are qf, qt, pt, and pf entries in this dictionary

    PowerFlow_line = []
    for i in 1:length(sol_eng["nw"])
        push!(PowerFlow_line, sol_eng["nw"][string(i)]["line"][Line]["pf"][Phase])
    end

    # This calculation compares the power flow through line 12_1 (From PMD), to the power injection into node 1 (From REopt). If the PMD and REopt models are connected, this should be zero or very close to zero.
    Mismatch_in_expected_powerflow = PowerFlow_line - REopt_power_injection[1:4000].data   # This is only valid for the model with only one REopt load on node 1

    # Visualize the mismatch to ensure the results are zero for each time step
    Plots.plot(collect(1:4000), Mismatch_in_expected_powerflow)
    Plots.xlabel!("Timestep")
    Plots.ylabel!("Mismatch between REopt and PMD (kW)")
    display(Plots.title!("REopt and PMD Mismatch: Node $(Node), Phase $(Phase)"))
end 


# Function to run the REopt analysis for the basic linear model type
function Microgrid_REopt_Model_BasicLinear(JuMP_Model, Microgrid_Inputs, ldf_inputs_dictionary, REoptInputs, TimeStamp)
    cd(Microgrid_Inputs.FolderLocation)
    ldf_inputs_dictionary = ldf_inputs_dictionary
    ps = REoptInputs
    
    StartTime = now() #Recording the start time
    NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"])) 

    FacilityMeter_Node = Microgrid_Inputs.FacilityMeter_Node
    MicrogridType = Microgrid_Inputs.MicrogridType
    AllowExportBeyondSubstation = Microgrid_Inputs.AllowExportBeyondSubstation
    SubstationExportLimit = Microgrid_Inputs.SubstationExportLimit
    GeneratorFuelGallonAvailable = Microgrid_Inputs.GeneratorFuelGallonAvailable
    OutageStartTimeStep = Microgrid_Inputs.SingleOutageStartTimeStep
    OutageStopTimeStep = Microgrid_Inputs.SingleOutageStopTimeStep

    TimeSteps = collect(1:(8760*Microgrid_Inputs.TimeStepsPerHour))

    # Add the LDF inputs
    # this can be done using two methods:
        # 1. importing an OpenDSS file for the lines and linecodes (the method used in this script)
        # 2. manually building out a distribution network information

    ldf_inputs = PowerFlowInputs(
        ldf_inputs_dictionary["LinesFileLocation"], 
        ldf_inputs_dictionary["SubstationLocation"], # this is the location of the substation bus (aka, where the power is being input into the network)
        ldf_inputs_dictionary["LineCodesFileLocation"];
        dsstransformersfilepath = ldf_inputs_dictionary["TransformersFileLocation"],
        Pload = ldf_inputs_dictionary["load_nodes"],
        Qload = ldf_inputs_dictionary["load_nodes"], 
        Sbase = ldf_inputs_dictionary["Sbase_input"],
        Vbase = ldf_inputs_dictionary["Vbase_input"],
        v0 = ldf_inputs_dictionary["v0_input"],  
        v_uplim = ldf_inputs_dictionary["v_uplim_input"],
        v_lolim = ldf_inputs_dictionary["v_lolim_input"],
        P_up_bound = ldf_inputs_dictionary["P_up_bound_input"],  # note, these are not in kW units (I think they are expressed as a per-unit system)
        P_lo_bound = ldf_inputs_dictionary["P_lo_bound_input"],
        Q_up_bound = ldf_inputs_dictionary["Q_up_bound_input"],
        Q_lo_bound = ldf_inputs_dictionary["Q_lo_bound_input"], 
        Ntimesteps = ldf_inputs_dictionary["T"]
    )

    # Determine the voltages at each line:
    LineNominalVoltages_Summary, BusNominalVoltages_Summary = DetermineLineNominalVoltage(ldf_inputs)
    
    # For a Community District microgrid:
        # Redefine the electricity tariff, if needed, for when the grid outage occurs - this will allow for power sharing between the nodes during an outage
    if MicrogridType == "CommunityDistrict"
        for x in REoptInputs
            x.s.electric_tariff.energy_rates[OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
            x.s.electric_tariff.export_rates[:WHL][OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        end 
    end

    m = JuMP_Model 
    @info "Building the REopt model"
    build_reopt!(m,ps)
    @info "Adding ldf constraints"
    build_power_flow!(m, ldf_inputs, ps)  # The ps is an input here because this input structure for "build_ldf!" is defined in REopt's extend.jl file

# Apply additional constraints based on user inputs:

# Constraints 1: For a behind-the-meter-microgrid:
LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Inputs.FacilityMeter_Node
if AllowExportBeyondSubstation == false # Prevent power from being exported to the grid beyond the node 1 meter:
    JuMP.@constraint(m, [t in TimeSteps], m[:Pᵢⱼ][LineFromSubstationToFacilityMeter,t] >= 0 ) 
else
    JuMP.@constraint(m, [t in TimeSteps], m[:Pᵢⱼ][LineFromSubstationToFacilityMeter,t] >=  -((SubstationExportLimit*1000)/ ldf_inputs.Sbase) )  
end 

# Constraints 2: For an off-grid microgrid
if MicrogridType == "Offgrid"
    # prevent power from flowing in from the substation
    @info "Adding constraints for an offgrid microgrid"    
    JuMP.@constraint(m, [t in TimeSteps], m[:Pᵢⱼ][LineFromSubstationToFacilityMeter,t] == 0 ) 
end 

# Constraints 3: If an outage is modeled, prevent power from flowing into the substation at those times
if (OutageStopTimeStep - OutageStartTimeStep) > 0
    @info "Adding an outage to the model"
    JuMP.@constraint(m, [t in OutageStartTimeStep:OutageStopTimeStep], m[:Pᵢⱼ][LineFromSubstationToFacilityMeter,t] == 0) 
else 
    @info "No outage in the model"
end

# Constraints 4: For a community islanded during a grid outage
if MicrogridType == "CommunityDistrict"
    @info "Applying additional constraints for a Community District microgrid"
    
    if (OutageStopTimeStep - OutageStartTimeStep) > 0
        #Prevent the generator from operating during non-grid outage times
        for Node in NodeList
            JuMP.@constraint(m, [t in 1:(OutageStartTimeStep-1)], m[Symbol("dvRatedProduction_"*Node)]["Generator",t] == 0 )
            JuMP.@constraint(m, [t in (OutageStopTimeStep+1):length(TimeSteps)], m[Symbol("dvRatedProduction_"*Node)]["Generator",t] == 0 )    
        end
    end 
end

# Constraints 5: For switches
if Microgrid_Inputs.Model_Switches == true 
    for i in keys(Microgrid_Inputs.Switch_Open_Timesteps)
        Switch_Open_Timesteps = Microgrid_Inputs.Switch_Open_Timesteps[i]
        @constraint(m, [t in Switch_Open_Timesteps], m[:Pᵢⱼ][i,t] == 0 )
    end
end

# Constraints 6: For power export to the grid
for p in ps
    if string(p.s.site.node) == p.s.settings.facilitymeter_node
        @info "Setting facility-level grid purchase to the power flow on line "*string("0-", FacilityMeter_Node)*", using the variable: "*string(" dvGridPurchase_", FacilityMeter_Node)
                
        if Microgrid_Inputs.AllowExportBeyondSubstation == true
            @info "Allowing export from the facility meter, which is limited to the defined export limit"
        
            @variable(m, binSubstationPositivePowerFlow[ts in p.time_steps], Bin)
            
            print("\n The time steps are: ")
            print(p.time_steps)
            print("\n The length of p.time_steps is: ")
            print(length(p.time_steps))

            for ts in p.time_steps
                @constraint(m, m[:binSubstationPositivePowerFlow][ts] => {(m[:Pᵢⱼ]["0-"*FacilityMeter_Node,ts]) >= 0 } )
                @constraint(m, !m[:binSubstationPositivePowerFlow][ts] => {(m[:Pᵢⱼ]["0-"*FacilityMeter_Node,ts]) <= 0 } )
            end

            # Set the power flowing through the line from the substation to be the grid purchase minus the dvProductionToGrid for node 15
            @constraint(m, [ts in p.time_steps],
                 (((m[:Pᵢⱼ]["0-"*FacilityMeter_Node,ts])*ldf_inputs.Sbase)/1000) == sum(m[Symbol("dvGridPurchase_"*FacilityMeter_Node)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - sum(m[Symbol("dvProductionToGrid_"*FacilityMeter_Node)]["PV", u, ts] for u in p.export_bins_by_tech["PV"])  # * binSubstationPositivePowerFlow[ts]
            )
            @constraint(m, [ts in p.time_steps],
                sum(m[Symbol("dvGridPurchase_"*FacilityMeter_Node)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) <= Microgrid_Inputs.SubstationImportLimit * binSubstationPositivePowerFlow[ts]
            )   
            @constraint(m, [ts in p.time_steps],
                sum(m[Symbol("dvProductionToGrid_"*FacilityMeter_Node)]["PV", u, ts] for u in p.export_bins_by_tech["PV"]) <= Microgrid_Inputs.SubstationExportLimit * (1 - binSubstationPositivePowerFlow[ts])
            )            
       else
           @info "Not allowing export from the facility meter"

           @constraint(m, [ts in p.time_steps],
               sum(m[Symbol("dvGridPurchase_"*FacilityMeter_Node)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) == (((m[:Pᵢⱼ]["0-"*FacilityMeter_Node,ts])*5000)/1000)
           )

           @constraint(m, [ts in p.time_steps],
               sum(m[Symbol("dvProductionToGrid_"*FacilityMeter_Node)]["PV", u, ts] for u in p.export_bins_by_tech["PV"]) == 0)
        end
        print("\n The export bins for the facility meter node are: ")
        print(p.export_bins_by_tech["PV"])
    end
end

# Constraint 7: Line constraints (allowing for upgradable lines)
all_lines_temp = []
    for j in ldf_inputs.busses
        for i in i_to_j(j, ldf_inputs)
            i_j = string(i*"-"*j)
            push!(all_lines_temp, string(i_j))
        end
    end
all_lines = unique!(all_lines_temp)

if Microgrid_Inputs.Model_Line_Upgrades == true
    line_upgrades_each_line, lines_for_upgrades, all_lines = line_upgrades(m, Microgrid_Inputs, ldf_inputs, all_lines)
    print("\n The lines for upgrades are (from the second print statement): ")
    print(lines_for_upgrades)
else
    lines_for_upgrades = []
    line_upgrades_each_line = Dict([])
end

constrain_KVL(m, ldf_inputs, line_upgrades_each_line, lines_for_upgrades, all_lines, Microgrid_Inputs)

# Constraint 8: For transformer upgrades
if Microgrid_Inputs.Model_Transformer_Upgrades == true
    transformer_upgrades_each_transformer, transformers_for_upgrades = transformer_upgrades(m, Microgrid_Inputs, ldf_inputs)
else
    for i in keys(ldf_inputs.transformers)
        if ldf_inputs.transformers[i]["Transformer Side"] == "downstream"           
                maxkva = parse(Float64, ldf_inputs.transformers[i]["MaximumkVa"])
                @constraint(m, m[:transformer_max_kva][i] == maxkva)
        end
    end
    transformer_upgrades_each_transformer = Dict([])
end

# Note: the objective accounts for costs of all REopt nodes input into the model, as well as lines and transformer upgrades if upgrades are included as inputs to the model

@expression(m, Costs, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in ps) )

if Microgrid_Inputs.Model_Line_Upgrades == true
    add_to_expression!(Costs, sum(m[:line_cost][line] for line in lines_for_upgrades))
end
if Microgrid_Inputs.Model_Transformer_Upgrades == true
    add_to_expression!(Costs, sum(m[:transformer_cost][transformer] for transformer in transformers_for_upgrades))
end

@objective(m, Min, m[:Costs])

@info "The optimization is starting"
optimize!(m)
@info "The optimization is complete. Reading the results."

results = reopt_results(m, ps) 

#Record the end time and compute the computation time
EndTime = now()
ComputationTime = EndTime - StartTime

# Process results from the solution

# The variables Pᵢⱼ and Qᵢⱼ are indexed by the line value (shown in the edges variable below) in the power_flow.jl model 
edges = [string(i*"-"*j) for j in ldf_inputs.busses for i in i_to_j(j, ldf_inputs)]

# The variables Pⱼ and Qⱼ are indexed by the bus value (in the power_flow_inputs) in the power_flow.jl model
    # Note: look at the value.(m[:Pᵢⱼ]) in the terminal to see the values and indexes
busses = ldf_inputs.busses

# Compute values for each line and store line power flows in a dataframe and dictionary 
DataLineFlow = zeros(7)
DataFrame_LineFlow = DataFrame(fill(Any[],7), [:LineCode, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Rated_Power_kW])
Dictionary_LineFlow_Power_Series = Dict([])

for j in ldf_inputs.busses
    for i in i_to_j(j, ldf_inputs)
    edge = string(i*"-"*j)

    NetRealLineFlow = (value.(m[:Pᵢⱼ][edge,:]).data* ldf_inputs.Sbase)/1000 
    NetReactiveLineFlow = (value.(m[:Qᵢⱼ][edge,:]).data*ldf_inputs.Sbase)/1000 

    linenormamps = value.(m[:line_max_amps][edge]) # get_ijlinenormamps(i,j,ldf_inputs)
    LineNominalVoltage = parse(Float64,LineNominalVoltages_Summary[edge])
    MaximumRatedPower_kW = 0.001*linenormamps*LineNominalVoltage

    DataLineFlow[1] = round(minimum(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[2] = round(maximum(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[3] = round(mean(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[4] = linenormamps
    DataLineFlow[5] = LineNominalVoltage
    DataLineFlow[6] = round(MaximumRatedPower_kW, digits=0)

    DataFrame_LineFlow_temp = DataFrame([("Line "*string(edge)) DataLineFlow[1] DataLineFlow[2] DataLineFlow[3] DataLineFlow[4] DataLineFlow[5] DataLineFlow[6]], [:LineCode, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Rated_Power_kW])
    DataFrame_LineFlow = append!(DataFrame_LineFlow,DataFrame_LineFlow_temp)
    
    # Also create a dictionary of the line power flows
    Dictionary_LineFlow_Power_Series_temp = Dict([(edge, Dict([
                                                        ("NetRealLineFlow", NetRealLineFlow),
                                                        ("NetReactiveLineFlow", NetReactiveLineFlow)
                                                    ]))
                                                    ])
    merge!(Dictionary_LineFlow_Power_Series, Dictionary_LineFlow_Power_Series_temp)

    end
end

# Compute values for each node:
Dictionary_Node_Data_Series = Dict([])

for bus in busses

    VoltageMagnitudeSquared = value.(m[:vsqrd][bus,:]).data 
    VoltageMagnitude = sqrt.(VoltageMagnitudeSquared) # note, this is represented as per unit voltage
    # note: changed the ldf_inputs.Vbase to be the Vbase for each node
    VoltageMagnitudekV = (sqrt.(VoltageMagnitudeSquared)*parse(Float64,BusNominalVoltages_Summary[bus]))/1000 # find the squareroot of the voltage magnitude squared, un-normalize it, and then convert it from V to kV  

    NetRealPowerInjection = (value.(m[:Pⱼ][bus,:]).data  * ldf_inputs.Sbase)/1000   # convert to kw by multiplying by ldf_inputs.Sbase and divide by 1000, as seen in the test_with_cplex.jl file
    NetReactivePowerInjection = (value.(m[:Qⱼ][bus,:]).data *ldf_inputs.Sbase)/1000 

    Dictionary_Node_Data_Series_temp = Dict([
                                        (bus, Dict([
                                            ("VoltageMagnitude_PerUnit", VoltageMagnitude),
                                            ("VoltageMagnitude_kV", VoltageMagnitudekV),
                                            ("NetRealPowerInjection", -NetRealPowerInjection),
                                            ("NetReactivePowerInjection", -NetReactivePowerInjection)
                                        ]))
                                        ])

    merge!(Dictionary_Node_Data_Series,Dictionary_Node_Data_Series_temp)
end

# Compute the total power flows:
TotalLoad_series = zeros(length(TimeSteps)) # initiate the total load series as zeros
for n in NodeList
    NodeNum = parse(Int,n)
    TotalLoad_series = TotalLoad_series + results[NodeNum]["ElectricLoad"]["load_series_kw"] 
end

Vbase_input = ldf_inputs_dictionary["Vbase_input"]
v_uplim_input = ldf_inputs_dictionary["v_uplim_input"]
v_lolim_input = ldf_inputs_dictionary["v_lolim_input"] 

# Determine all of the nodes with PV and determine total PV output across the entire network
NodesWithPV = []
for i in keys(results)
    if "PV" in keys(results[i])
        push!(NodesWithPV, i)
    end
end
PVOutput = zeros(length(TimeSteps))
for NodeNumberTemp in NodesWithPV
    PVOutput = PVOutput + results[NodeNumberTemp]["PV"]["electric_to_load_series_kw"] + results[NodeNumberTemp]["PV"]["electric_to_grid_series_kw"]
end

# Determine all of the nodes with Battery
NodesWithBattery = []
for i in keys(results)
    if "ElectricStorage" in keys(results[i])
        push!(NodesWithBattery, i)
    end
end
BatteryOutput = zeros(length(TimeSteps))
for NodeNumberTemp in NodesWithBattery
    if results[NodeNumberTemp]["ElectricStorage"]["size_kw"] > 0  # include this if statement to prevent trying to add in empty electric storage time series vectors
        BatteryOutput = BatteryOutput + results[NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"] + results[NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"] 
    end
end

# Determine all of the nodes with generator
NodesWithGenerator = []
for i in keys(results)
    if "Generator" in keys(results[i])
        push!(NodesWithBattery, i)
    end
end
GeneratorOutput = zeros(length(TimeSteps))
for NodeNumberTemp in NodesWithGenerator
    GeneratorOutput = GeneratorOutput + results[NodeNumberTemp]["Generator"]["electric_to_load_series_kw"] + results[NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"] + results[NodeNumberTemp]["Generator"]["electric_to_storage_series_kw"] 
end

# Generate a series of plots if the "Generate_Results_Plots" input is set to true
if Microgrid_Inputs.Generate_Results_Plots == true
    @info "Generating results plots"

    # Plot the voltage drop through the entire system
        # Determine the line distance from each node to the substation
        nodes_evaluate = ldf_inputs.busses # NodeList
        distances = Dict([])
        for node_evaluate in nodes_evaluate
            node = node_evaluate
            distance_temp = 0
            if node_evaluate == ldf_inputs.substation_bus
                    # Do nothing because there are no busses upstream of the substation
            else
                for i in collect(1:(length(NodeList)+1))                
                    upstream_node = i_to_j(node, ldf_inputs)[1]
                    if upstream_node == ldf_inputs.substation_bus
                        distance_temp = distance_temp + get_ijlinelength(upstream_node, node, ldf_inputs)
                        break # break out of the for-loop
                    else
                        distance_temp = distance_temp + get_ijlinelength(upstream_node, node, ldf_inputs)
                        node = upstream_node
                    end
                end
            end
            distances_temp = Dict([node_evaluate => distance_temp]) 
            merge!(distances, distances_temp)
        end

        ColorOptions = ["black","blue","red","green","grey","orange","cyan"] # Add more colors if the network has more than 7 nominal bus voltages
        Unique_Voltages = unique!(collect(values(BusNominalVoltages_Summary)))
        Voltage_Color_Pairing = Dict([])
        for index in collect(1:length(Unique_Voltages))
            temp_dict = Dict([Unique_Voltages[index] => ColorOptions[index]])
            merge!(Voltage_Color_Pairing, temp_dict)
        end
        print("\n The unique voltages are: ")
        print(Unique_Voltages)
        substation_nom_voltage = BusNominalVoltages_Summary[ldf_inputs.substation_bus]
        print("\n The nominal voltage of the substation is: $(substation_nom_voltage)")
        print(" The type of the voltage variable is: ")
        print(typeof(substation_nom_voltage))
        Color = Voltage_Color_Pairing[substation_nom_voltage]
        Plots.plot([distances[ldf_inputs.substation_bus]], [Dictionary_Node_Data_Series[ldf_inputs.substation_bus]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], marker=(:circle,6), markercolor=Color, linewidth=3, linecolor=Color, label=BusNominalVoltages_Summary[ldf_inputs.substation_bus]*" V", size = (600,400))
        Unique_Voltages = filter(x -> x != BusNominalVoltages_Summary[ldf_inputs.substation_bus], Unique_Voltages)
        #ColorChoice=2
        for node in ldf_inputs.busses
            print("The loop number is: $(node)")
            #print("\n The unique voltages array is: ")
            #print(Unique_Voltages)
            if node == ldf_inputs.substation_bus
                # Do nothing, because the substation node is plotted above
            else
                # Find the upstream node for plotting
                upstream_node = i_to_j(node, ldf_inputs)[1]
                Color = Voltage_Color_Pairing[BusNominalVoltages_Summary[node]]
                Plots.plot!([distances[upstream_node], distances[node]], [Dictionary_Node_Data_Series[upstream_node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep], Dictionary_Node_Data_Series[node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], linecolor = Color, linewidth=3, label=false)

                if BusNominalVoltages_Summary[node] in Unique_Voltages  # Plot the marker with a label             
                    Plots.plot!([distances[node]], [Dictionary_Node_Data_Series[node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], marker = (:circle,6), markercolor = Color, linewidth=3, linecolor=Color, label=BusNominalVoltages_Summary[node]*" V")
                    #print("\n ColorChoice is:")
                    #print(ColorChoice)
                    #ColorChoice = ColorChoice + 1
                    Unique_Voltages = filter(x -> x != BusNominalVoltages_Summary[node], Unique_Voltages)
                else # Plot the marker without the label
                    Plots.plot!([distances[node]], [Dictionary_Node_Data_Series[node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], marker = (:circle,6), markercolor = Color, linewidth=0, linecolor="white", label=false) 
                end
            end
        end
        Plots.xlabel!("Line Distance from Substation")
        Plots.ylabel!("Per Unit Voltage")
        display(Plots.title!("Voltage Plot for All Busses"))
        Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/VoltagePlot.png")
       
    # Plot showing that the voltage is within defined +/- percentage of the nominal voltage
    mkdir(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Voltage_at_Each_Node_Plots") 
    for n in NodeList
        Plots.plot(Dictionary_Node_Data_Series[n]["VoltageMagnitude_kV"], label = "Voltage Magnitude (kV)", linewidth = 2, line = (:dash), size = (1000,400))
        Plots.plot!(parse(Float64,BusNominalVoltages_Summary[n])*v_uplim_input*(ones(length(TimeSteps))/1000), label = "Upper limit (kV)")
        Plots.plot!(parse(Float64,BusNominalVoltages_Summary[n])*v_lolim_input*(ones(length(TimeSteps))/1000), label = "Lower limit (kV)")
        Plots.xlabel!("Hour of the Year") 
        Plots.ylabel!("Voltage (kV)")
        #Plots.xlims!(4000,4100)
        display(Plots.title!("Node "*n*": Voltage"))
        Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Voltage_at_Each_Node_Plots/Node_$(n)_Voltage"*TimeStamp*".png")
    end 

    # Plot, for a defined time, how the per-unit voltage is changing through the system
        # Note: use per-unit so can track voltage drop through lines that have different nominal voltages
    if Microgrid_Inputs.PlotVoltageDrop == true
        NodesToPlot = Microgrid_Inputs.PlotVoltageDrop_NodeNumbers
        timestep_voltage = Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep
        VoltagesAtNodes = [ Dictionary_Node_Data_Series[NodesToPlot[1]]["VoltageMagnitude_PerUnit"][timestep_voltage]]
        for x in 2:length(NodesToPlot)
            push!(VoltagesAtNodes, Dictionary_Node_Data_Series[NodesToPlot[x]]["VoltageMagnitude_PerUnit"][timestep_voltage])
        end 
        Plots.plot(VoltagesAtNodes, marker = (:circle,3))
        display(Plots.title!("Voltage Change Through System, timestep = "*string(timestep_voltage)))
    end

    #Plot the network-wide power use 
    days = TimeSteps/(24* (length(TimeSteps)/8760))
    Plots.plot(days, TotalLoad_series, label="Total Load")
    Plots.plot!(days, PVOutput, label="Combined PV Output")
    Plots.plot!(days, BatteryOutput, label = "Combined Battery Output")
    Plots.plot!(days, GeneratorOutput, label = "Combined Generator Output")
    Plots.plot!(days, Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"])

    if (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/(24 * (length(TimeSteps)/8760) )
        OutageStop_Line = OutageStopTimeStep/(24 * (length(TimeSteps)/8760) )
        Plots.plot!([OutageStart_Line, OutageStart_Line],[0,maximum(TotalLoad_series)], label= "Outage Start")
        Plots.plot!([OutageStop_Line, OutageStop_Line],[0,maximum(TotalLoad_series)], label= "Outage End")
    else
        Plots.xlims!(4000/(24* (length(TimeSteps)/8760)),4100/(24* (length(TimeSteps)/8760)))
    end
    display(Plots.title!("System Wide Power Demand and Generation"))
    Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/SystemWidePowerUse")

    # Plot the real power load and real power injection data for each REopt node:
    mkdir(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Power_Flow_at_Each_Node")
    for n in NodeList # NodeList is a list of the REopt nodes
        NodeNumberTemp = parse(Int,n) # This converst the node number string to an integer
        Plots.plot(Dictionary_Node_Data_Series[n]["NetRealPowerInjection"], label="Power Injection", linewidth = 2) #, line = (:dash, 2))  # why divide by 1000?
        Plots.plot!(results[NodeNumberTemp]["ElectricLoad"]["load_series_kw"], label = "Load", linewidth = 1, line = (:dash, 2)) 
        if "PV" in keys(results[NodeNumberTemp])
            Plots.plot!(results[NodeNumberTemp]["PV"]["electric_to_load_series_kw"], label = "PV to load", linewidth = 2) #, line = (:dash, 2)) 
            Plots.plot!(-results[NodeNumberTemp]["PV"]["electric_to_grid_series_kw"], label = "PV to grid", linewidth = 2, line = (:dash)) 
        end 
        if "ElectricStorage" in keys(results[NodeNumberTemp])
            Plots.plot!(results[NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"], label = "Battery to load", linewidth = 2) 
            Plots.plot!(-results[NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"], label = "Battery Export to Grid", linewidth = 2) 
        end
        if "Generator" in keys(results[NodeNumberTemp])
            Plots.plot!(results[NodeNumberTemp]["Generator"]["electric_to_load_series_kw"].data, label = "Generator to load", linewidth = 2) 
            Plots.plot!(-results[NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"].data, label = "Generator Export to Grid", linewidth = 2) 
        end 
        
        Plots.xlabel!("Hour of the Year")
        Plots.ylabel!("Power (kW)")
        Plots.title!("Node "*string(NodeNumberTemp)*": Power Series")
        display(Plots.xlims!(Microgrid_Inputs.ResultPlotsStartTimeStep,Microgrid_Inputs.ResultPlotsEndTimeStep))

        # Plot showing export of the generator power
        if "Generator" in keys(results[NodeNumberTemp])
            Plots.plot(Dictionary_Node_Data_Series[n]["NetRealPowerInjection"], label="Power Injection", linewidth = 2) #, line = (:dash, 2))  # why divide by 1000?
            Plots.plot!(results[NodeNumberTemp]["ElectricLoad"]["load_series_kw"], label = "Load", linewidth = 1, line = (:dash, 2)) 
            if "PV" in keys(results[NodeNumberTemp])
                Plots.plot!(results[NodeNumberTemp]["PV"]["electric_to_load_series_kw"], label = "PV to load", linewidth = 2) #, line = (:dash, 2)) 
                Plots.plot!(results[NodeNumberTemp]["PV"]["electric_to_grid_series_kw"], label = "PV to grid", linewidth = 2) 
            end 
            if "ElectricStorage" in keys(results[NodeNumberTemp])
                Plots.plot!(results[NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"], label = "Battery to load", linewidth = 2) 
                Plots.plot!(-results[NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"], label = "Battery Export to Grid", linewidth = 2) 
            end
            if "Generator" in keys(results[NodeNumberTemp])
                Plots.plot!(results[NodeNumberTemp]["Generator"]["electric_to_load_series_kw"].data, label = "Generator to load", linewidth = 2) 
                Plots.plot!(-results[NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"].data, label = "Generator Export to Grid", linewidth = 2) 
            end 
            Plots.xlabel!("Hour of the Year")
            Plots.ylabel!("Power (kW)")
            Plots.title!("Node "*string(NodeNumberTemp)*": Power Series, showing max generator export")
            MiddleValue = findmax(results[NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"].data)[2]
            if MiddleValue < 50
                MiddleValue = 50
            end
            display(Plots.xlims!(MiddleValue-50,MiddleValue+50))
        end 
        Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Power_Flow_at_Each_Node/Node_$(n)_PowerFlows"*TimeStamp*".png")
    end

    # Plot all of the real and reactive power flow through each distribution line
    mkdir(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Power_Flow_through_Each_Line")
    for edge in edges
        Plots.plot(Dictionary_LineFlow_Power_Series[edge]["NetRealLineFlow"], label = "Real Power Flow" )
        Plots.plot!(Dictionary_LineFlow_Power_Series[edge]["NetReactiveLineFlow"], label = "Reactive Power Flow" )
        Plots.xlabel!("Hour of the Year")
        Plots.ylabel!("Power (kW)")
        Plots.title!("Distribution Line $(edge): Power Flow")
        display(Plots.xlims!(Microgrid_Inputs.ResultPlotsStartTimeStep,Microgrid_Inputs.ResultPlotsEndTimeStep))
        Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Power_Flow_through_Each_Line/Line_$(edge)_PowerFlows"*TimeStamp*".png")
    end
end 

if Microgrid_Inputs.Model_Transformer_Upgrades == true
    transformer_upgrade_results = DataFrame(fill(Any[], 4), [:Transformer, :Upgraded, :MaximumkVA, :UpgradeCost])
    for transformer in transformers_for_upgrades
        number_of_entries = length(transformer_upgrades_each_transformer[transformer]["max_kva"])
        dv = "Bin"*transformer
        maximum_kva = sum(value.(m[Symbol(dv)][i])*transformer_upgrades_each_transformer[transformer]["max_kva"][i] for i in 1:number_of_entries)
        upgraded_cost = value.(m[Symbol("transformer_cost")][transformer]) 

        if value.(m[Symbol(dv)][1]) != 1
            upgraded = "Yes"
        else
            upgraded = "No"
        end

        transformer_upgrade_results_temp = DataFrame([transformer upgraded maximum_kva upgraded_cost ], [:Transformer, :Upgraded, :MaximumkVA, :UpgradeCost])
        transformer_upgrade_results = append!(transformer_upgrade_results, transformer_upgrade_results_temp)
    end
    transformer_upgrade_options = transformer_upgrades_each_transformer
else
    transformer_upgrade_options = "N/A"
    transformer_upgrade_results = "N/A"
end

if Microgrid_Inputs.Model_Line_Upgrades == true
    line_upgrade_results = DataFrame(fill(Any[], 6), [:LineCode, :Upgraded, :MaximumRatedAmps, :rmatrix, :xmatrix, :UpgradeCost])
    for line in lines_for_upgrades
        number_of_entries = length(line_upgrades_each_line[line]["max_amperage"])
        dv = "Bin"*line
        maximum_amps = sum(value.(m[Symbol(dv)][i])*line_upgrades_each_line[line]["max_amperage"][i] for i in 1:number_of_entries)
        rmatrix = sum(value.(m[Symbol(dv)][i])*line_upgrades_each_line[line]["rmatrix"][i] for i in 1:number_of_entries)
        xmatrix = sum(value.(m[Symbol(dv)][i])*line_upgrades_each_line[line]["xmatrix"][i] for i in 1:number_of_entries)
        upgraded_cost = value.(m[Symbol("line_cost")][line]) 

        if value.(m[Symbol(dv)][1]) != 1
            upgraded = "Yes"
        else
            upgraded = "No"
        end

        line_upgrade_results_temp = DataFrame([line upgraded maximum_amps rmatrix xmatrix upgraded_cost ], [:LineCode, :Upgraded, :MaximumRatedAmps, :rmatrix, :xmatrix, :UpgradeCost])
        line_upgrade_results = append!(line_upgrade_results, line_upgrade_results_temp)
    end    
    line_upgrade_options = line_upgrades_each_line
else
    line_upgrade_options = "N/A"
    line_upgrade_results = "N/A"
end

# Building the input dictionary for the microgrid outage simulator:
if Microgrid_Inputs.RunOutageSimulator == true
    DataDictionaryForEachNode = GenerateInputsForOutageSimulator(Microgrid_Inputs, REopt_results)
else
    @info "Not running the outage simulator"
    DataDictionaryForEachNode = "The outage simulator was not used"
end

return DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results, DataFrame_LineFlow, LineNominalVoltages_Summary, BusNominalVoltages_Summary, m, lines_for_upgrades, line_upgrade_options, transformer_upgrade_options, line_upgrade_results, transformer_upgrade_results, line_upgrades_each_line, all_lines 
end 

function GenerateREoptNodesList(Microgrid_Inputs)
    REopt_nodes = []
    for i in Microgrid_Inputs.REoptInputsList
        if string(i["Site"]["node"]) != Microgrid_Inputs.FacilityMeter_Node
            push!(REopt_nodes, i["Site"]["node"])
        end
    end
    return REopt_nodes
end

function GenerateInputsForOutageSimulator(Microgrid_Inputs, REopt_results)
    results = REopt_results

            # Temporary including this code
            REopt_inputs_all_nodes = Microgrid_Inputs.REoptInputsList
            # Prepare loads for using with the outage simulator, if the fraction method is used for determining the critical load
            if  Microgrid_Inputs.Critical_Load_Method == "Fraction"
                load_profiles_for_outage_sim_if_using_the_fraction_method = Dict([])
                for REopt_inputs in REopt_inputs_all_nodes
                    load_profiles_for_outage_sim_if_using_the_fraction_method[REopt_inputs["Site"]["node"]] = deepcopy( REopt_inputs["ElectricLoad"]["loads_kw"] )
                end
                Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method = load_profiles_for_outage_sim_if_using_the_fraction_method
            else
                Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method = ""
            end
            # End of temporarily included code
            
    TimeSteps = collect(1:(8760*Microgrid_Inputs.TimeStepsPerHour))
    NodeList = string.(GenerateREoptNodesList(Microgrid_Inputs))
    print("\n The node list is:")
    print(NodeList)
    print("\n the keys of the results are: ")
    print(keys(results))
    # Define the critical loads
    critical_loads_kw = Dict([])
    if Microgrid_Inputs.Critical_Load_Method == "Fraction"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs.Critical_Load_Fraction[NodeList[i]] * Microgrid_Inputs.load_profiles_for_outage_sim_if_using_the_fraction_method[parse(Int,NodeList[i])]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs.TimeStepsPerHour)
            end
        end
    elseif Microgrid_Inputs.Critical_Load_Method == "TimeSeries"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs.Critical_Load_TimeSeries[NodeList[i]]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs.TimeStepsPerHour)
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
        if NodeList[1] in keys(Microgrid_Inputs.GeneratorFuelGallonAvailable)
            GeneratorFuelGallonAvailable = Microgrid_Inputs.GeneratorFuelGallonAvailable[NodeList[1]]
        else
            GeneratorFuelGallonAvailable = 0
        end
    else
        GeneratorSize_results = 0
        GeneratorFuelGallonAvailable = 0
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
            ("Fuel_tank_capacity_gal", GeneratorFuelGallonAvailable),
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
            if NodeList[i] in keys(Microgrid_Inputs.GeneratorFuelGallonAvailable)
                GeneratorFuelGallonAvailable = Microgrid_Inputs.GeneratorFuelGallonAvailable[NodeList[i]]
            else
                GeneratorFuelGallonAvailable = 0
            end 
        else
            GeneratorSize_results_B = 0
            GeneratorFuelGallonAvailable = 0
        end 
        DictionaryToAdd = Dict([
            (NodeList[i],Dict([
                ("loads_kw", critical_loads_kw[NodeList[i]]),
                ("PVproductionprofile", PVProductionProfile_results_B),
                ("GeneratorSize", GeneratorSize_results_B),
                ("Battery_charge_kwh", BatteryChargekwh_B),
                ("Battery_kw", Batterykw_B),
                ("Battery_kwh", Batterykwh_B),
                ("Fuel_tank_capacity_gal", GeneratorFuelGallonAvailable),
                ("battery_roundtrip_efficiency",0.95)
                ])),
        ]) 
        merge!(DataDictionaryForEachNode, DictionaryToAdd)
    end 
return DataDictionaryForEachNode
end


function line_upgrades(m, Microgrid_Inputs, powerflow_inputs, all_lines)
    # Function for modeling line upgrades

    # Create a list lines that are upgradable
    lines_for_upgrades_temp = []
    for i in keys(Microgrid_Inputs.Line_Upgrade_Options)
        push!(lines_for_upgrades_temp, Microgrid_Inputs.Line_Upgrade_Options[i]["locations"]) 
    end
    lines_for_upgrades_temp2 = unique!(lines_for_upgrades_temp)
    lines_for_upgrades = lines_for_upgrades_temp2[1]

    p = powerflow_inputs
    
    print("\n The all_lines variable in the line_upgrades function is: $(all_lines) ")
    print("\n The lines for upgrades are (from print statement #1): $(lines_for_upgrades) ")

    # Define variables for the line cost
    @variable(m, line_cost[lines_for_upgrades] >= 0 )

    line_upgrade_options_each_line = Dict([])
    for line_name in all_lines
        firstnode = string(strip(chop(line_name, tail = sizeof(line_name)  -findfirst("-", line_name)[1]+1)))
        secondnode = string(strip(chop(line_name,head= findfirst("-", line_name)[end], tail=0 )))
        if line_name in lines_for_upgrades
            # Generate a dictionary for the options, organized so that the keys are the lines and the values are options for each line
            for i in keys(Microgrid_Inputs.Line_Upgrade_Options), j in Microgrid_Inputs.Line_Upgrade_Options[i]["locations"]
                if line_name == j
                    if line_name ∉ keys(line_upgrade_options_each_line) 
                        line_norm_amps = get_ijlinenormamps(firstnode, secondnode, p)
                        line_code = get_ijlinecode(firstnode,secondnode,p) 
                        line_upgrade_options_each_line[line_name] = Dict([("max_amperage", [line_norm_amps, Microgrid_Inputs.Line_Upgrade_Options[i]["max_amps"]]),
                                                                          ("cost_per_length", [0, Microgrid_Inputs.Line_Upgrade_Options[i]["cost_per_unit_length"]]),
                                                                          ("rmatrix", [p.Zdict[line_code]["rmatrix"], Microgrid_Inputs.Line_Upgrade_Options[i]["rmatrix"]]),
                                                                          ("xmatrix", [p.Zdict[line_code]["xmatrix"], Microgrid_Inputs.Line_Upgrade_Options[i]["xmatrix"]])
                                                                ])
                    else
                        push!(line_upgrade_options_each_line[line_name]["max_amperage"], Microgrid_Inputs.Line_Upgrade_Options[i]["max_amps"])
                        push!(line_upgrade_options_each_line[line_name]["cost_per_length"], Microgrid_Inputs.Line_Upgrade_Options[i]["cost_per_unit_length"])
                        push!(line_upgrade_options_each_line[line_name]["rmatrix"], Microgrid_Inputs.Line_Upgrade_Options[i]["rmatrix"])
                        push!(line_upgrade_options_each_line[line_name]["xmatrix"], Microgrid_Inputs.Line_Upgrade_Options[i]["xmatrix"])
                    end
                end
            end
            number_of_entries = length(line_upgrade_options_each_line[line_name]["max_amperage"])
            dv = "Bin"*line_name
            m[Symbol(dv)] = @variable(m, [1:number_of_entries], base_name=dv, Bin)
            line_length = get_ijlinelength(firstnode, secondnode, p)

            @constraint(m, m[:line_max_amps][line_name] == sum(m[Symbol(dv)][i]*line_upgrade_options_each_line[line_name]["max_amperage"][i] for i in 1:number_of_entries))
            @constraint(m, m[:line_cost][line_name] == line_length * sum(m[Symbol(dv)][i]*line_upgrade_options_each_line[line_name]["cost_per_length"][i] for i in 1:number_of_entries))
            @constraint(m, sum(m[Symbol(dv)][i] for i in 1:number_of_entries) == 1)

        else
            # If the line is not a line that can be upgraded (based on the user inputs), set the max amps, rmatrix, and xmatrix based on the user inputs
            # Note: the constraints for this are added in the power_flow.jl file
        end
    end
    return line_upgrade_options_each_line, lines_for_upgrades, all_lines
end

function transformer_upgrades(m, Microgrid_Inputs, powerflow_inputs)
    # Function for modeling transformer upgrades

    # Create list of transformers to upgrade
        # Note: transformers are identified here by the downstream node
    transformers_for_upgrades_temp = []
    for i in keys(Microgrid_Inputs.Transformer_Upgrade_Options)
        push!(transformers_for_upgrades_temp, Microgrid_Inputs.Transformer_Upgrade_Options[i]["downstream_node"])
    end
    transformers_for_upgrades_temp2 = unique!(transformers_for_upgrades_temp)    
    transformers_for_upgrades = transformers_for_upgrades_temp2[1]

    # Print some data:
    print("\n Transformers for upgrades are: ")
    print(transformers_for_upgrades)

    # Create list of all transformers:
    p = powerflow_inputs
    all_transformers = []
    for i in keys(p.transformers) 
        if p.transformers[i]["Transformer Side"] == "downstream"
            push!(all_transformers, i)
        end
    end

    # Create variables
    @variable(m, transformer_cost[transformers_for_upgrades] >= 0)
    transformer_options_each_transformer = Dict([])

    # Print some data:
    print("\n All transformers are: ")
    print(all_transformers)

    for transformer_name in all_transformers
        transformer_name = string(transformer_name)
        print("\n the transformer_name is: ")
        print(transformer_name)
        if transformer_name in transformers_for_upgrades
            for i in keys(Microgrid_Inputs.Transformer_Upgrade_Options), j in Microgrid_Inputs.Transformer_Upgrade_Options[i]["downstream_node"]
                if transformer_name == j
                    if transformer_name ∉ keys(transformer_options_each_transformer)
                        transformer_options_each_transformer[transformer_name] = Dict([ ("max_kva", [parse(Int64, p.transformers[transformer_name]["MaximumkVa"]), Microgrid_Inputs.Transformer_Upgrade_Options[i]["max_kva"]]),
                                                                                        ("cost", [0, Microgrid_Inputs.Transformer_Upgrade_Options[i]["cost"]])
                                                                                        ])
                    else
                        push!(transformer_options_each_transformer[transformer_name]["max_kva"], Microgrid_Inputs.Transformer_Upgrade_Options[i]["max_kva"])
                        push!(transformer_options_each_transformer[transformer_name]["cost"], Microgrid_Inputs.Transformer_Upgrade_Options[i]["cost"])
                    
                    end
                end
            end
            print("\n The transformer options for each transformer are: ")
            print(transformer_options_each_transformer)

            number_of_entries = length(transformer_options_each_transformer[transformer_name]["max_kva"])
            dv = "Bin"*transformer_name
            m[Symbol(dv)] = @variable(m, [1:number_of_entries], base_name=dv, Bin)

            print("\n The number of entries are: $(number_of_entries)")

            @constraint(m, m[:transformer_max_kva][transformer_name] == sum(m[Symbol(dv)][i]*transformer_options_each_transformer[transformer_name]["max_kva"][i] for i in 1:number_of_entries))
            @constraint(m, m[:transformer_cost][transformer_name] == sum(m[Symbol(dv)][i]*transformer_options_each_transformer[transformer_name]["cost"][i] for i in 1:number_of_entries))
            @constraint(m, sum(m[Symbol(dv)][i] for i in 1:number_of_entries) == 1)
        else
            @constraint(m, m[:transformer_max_kva][transformer_name] == p.transformers[transformer_name]["MaximumkVa"])
        end
    end

    return transformer_options_each_transformer, transformers_for_upgrades
end


# Use the function below to run the outage simulator 
function Microgrid_OutageSimulator( DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp;
                                    # Inputs for the BasicLinear model 
                                    line_max_amps="", lines_rmatrix="", lines_xmatrix="", lines_for_upgrades="", ldf_inputs_dictionary = ldf_inputs_dictionary,
                                    line_upgrades_each_line="", all_lines="", transformer_max_kva="", BasicLinear_model="",
                                    # Inputs for the PMD model: 
                                    pmd_model="", LineInfo_PMD="",
                                    # Inputs for both models 
                                    NumberOfOutagesToTest = 15, OutageLength_TimeSteps_Input = 1)
    
NodeList = string.(GenerateREoptNodesList(Microgrid_Inputs)) #collect(keys(ldf_inputs_dictionary["load_nodes"]))

OutageLength_TimeSteps = OutageLength_TimeSteps_Input

NumberOfTimeSteps = Microgrid_Inputs.TimeStepsPerHour * 8760
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

if Microgrid_Inputs.Model_Type == "BasicLinear"

    m_outagesimulator = BasicLinear_model

    OutageSimulator_LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Inputs.FacilityMeter_Node

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
elseif Microgrid_Inputs.Model_Type == "PowerModelsDistribution"
    
    OutageSimulator_LineFromSubstationToFacilityMeter = Microgrid_Inputs.Substation_Node*"-"*Microgrid_Inputs.FacilityMeter_Node
end

# Define the outage start time steps based on the number of outages
IncrementSize_ForOutageStartTimes = Int(floor(MaximumTimeStepToEvaluate_limit/NumberOfOutagesToTest))
RunsTested = 0
index = 0
for x in 1:MaximumTimeStepToEvaluate
    print("\n Outage Simulation Run # "*string(x)*"  of  "*string(MaximumTimeStepToEvaluate)*" runs")
    RunsTested = RunsTested + 1
    i = Int(x*IncrementSize_ForOutageStartTimes)
    TotalTimeSteps = 8760*Microgrid_Inputs.TimeStepsPerHour
    #empty!(m_outagesimulator) # empties the JuMP model so that the same variables names can be applied in the new model
    

    # Generate the power flow constraints
    if Microgrid_Inputs.Model_Type == "BasicLinear"
        empty!(m_outagesimulator) # empties the JuMP model so that the same variables names can be applied in the new model

        m_outagesimulator = JuMP_Model
        power_flow_add_variables(m_outagesimulator, ldf_inputs_new)
        constrain_power_balance(m_outagesimulator, ldf_inputs_new)
        constrain_substation_voltage(m_outagesimulator, ldf_inputs_new)
        create_line_variables(m_outagesimulator, ldf_inputs_new)
        constrain_KVL(m_outagesimulator, ldf_inputs_new, line_upgrades_each_line, lines_for_upgrades, all_lines, Microgrid_Inputs)
    elseif Microgrid_Inputs.Model_Type == "PowerModelsDistribution"
        # Creates the PMD model and outputs the model itself
        if x != 1
            empty!(m_outagesimulator)  # empty the JuMP model if it has been defined previously
        end
        m_outagesimulator, pm, data_math_mn = Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs)
    end
    
    for n in NodeList
        GenPowerRating = DataDictionaryForEachNode[n]["GeneratorSize"]  
        TimeSteps = OutageLength_TimeSteps
        TimeStepsPerHour = Microgrid_Inputs.TimeStepsPerHour
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

        # Power flow to the loads:
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
        @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("FuelUsage_"*n)][ts] .== (m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts] + m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts])*(1/TimeStepsPerHour)*GalPerkwh)
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
                                                                                                    (((m_outagesimulator[Symbol("SumOfBatFlows_"*n)][t]))/TimeStepsPerHour) )
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
                                                        m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts]   
                                                        .== round.((DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps-1)]), digits =2)[ts])
    end 
    
    # Connect the REopt model and power flow model

    if Microgrid_Inputs.Model_Type == "BasicLinear"
        # Constrain the loads
        constrain_loads(m_outagesimulator, ldf_inputs_new, REopt_dictionary) 
        
        # Define the parameters of the lines
        for j in ldf_inputs_new.busses
            for i in i_to_j(j, ldf_inputs_new)
                i_j = string(i*"-"*j)
                JuMP.@constraint(m_outagesimulator, m_outagesimulator[:line_max_amps][i_j] .== line_max_amps[i_j])
                
                # Define the new xmatrix and rmatrix for any upgradable lines
                if Microgrid_Inputs.Model_Line_Upgrades == true && Microgrid_Inputs.Nonlinear_Solver == true
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

    elseif Microgrid_Inputs.Model_Type == "PowerModelsDistribution"
        Build_REopt_and_Link_To_PMD(m, pm, Microgrid_Settings, data_math_mn)
        line = "substationline"
        timesteps = collect(outagestart:outageend)
        LineInfo = LineInfo_PMD # defined in the inputs to the function
        RestrictLinePowerFlow(pm, m, line, timesteps, LineInfo; Off_Grid=true)

    end

    # Determine all of the nodes with PV
    NodesWithPV = []
    for p in NodeList 
        if maximum(DataDictionaryForEachNode[p]["PVproductionprofile"]) > 0
            push!(NodesWithPV, p)
        end
    end 

    # Objective function, which is formulated to maximize the PV power that is used to meet the load
    @objective(m_outagesimulator, Max, sum(sum(m_outagesimulator[Symbol(string("dvPVToLoad_", n))]) for n in NodesWithPV))
    
    if Microgrid_Inputs.Model_Type == "BasicLinear"
        runresults = optimize!(m_outagesimulator)
        TerminationStatus = string(termination_status(m_outagesimulator))
        print("\n The result from run #"*string(RunsTested)*" is: "*TerminationStatus)
    elseif Microgrid_Inputs.Model_Type == "PowerModelsDistribution"
        results = PMD.optimize_model!(pm) 
        TerminationStatus = string(results["termination_status"])
        print("\n The result from run #"*string(RunsTested)*" is: "*TerminationStatus)
    end

    if TerminationStatus == "OPTIMAL"
        SuccessfullySolved = SuccessfullySolved + 1

        # TODO: change the calculation of the fuel remaining so it automatically calculates the fuel left on nodes with generators
        #print("\n the fuel left is: "*string(value.(m_outagesimulator[Symbol("FuelLeft_3")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_4")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_6")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_10")])) * " gal")
                
        if Microgrid_Inputs.Generate_Results_Plots == true
            @info "Generating results plots from the outage simulator, if the defined run numbers for creating plots survived the outage"

            # Generate plots for the outage simulator run numbers defined in the Microgrid_Inputs dictionary 
            if x in Microgrid_Inputs.RunNumbersForPlottingOutageSimulatorResults
                mkdir(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)")
                # plot the dispatch for each of the REopt nodes for the outage that is being tested
                for n in NodeList
                    Plots.plot(value.(m_outagesimulator[Symbol("dvPVToLoad_"*n)]), label = "PV to Load", linewidth = 3)
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToLoad_"*n)]), label = "Gen to Load", linewidth = 3)
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load", linewidth = 3)
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToLoad_"*n)]), label = "Grid to Load", linewidth = 3)
                    Plots.plot!(DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps-1)], label = "Total Load", linecolor = (:black)) # line = (:dash), linewidth = 1)
                    Plots.xlabel!("Time Step") 
                    Plots.ylabel!("Power (kW)") 
                    display(Plots.title!("Node "*n*": Load Balance, outage timestep: "*string(i)*" of "*string(TotalTimeSteps)))
                    Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Load_Balance_"*TimeStamp*".png")
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
                    Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Power_Export_"*TimeStamp*".png")
                
                    # Plot the battery flows
                    Plots.plot(-value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load")
                    Plots.plot!(-value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToBat_"*n)]), label = "Grid to Battery")
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvPVToBat_"*n)]), label = "PV to Battery")
                    Plots.xlabel!("Time Step")
                    Plots.ylabel!("Power (kW)")
                    display(Plots.title!("Node "*n*": Battery Flows, outage "*string(i)*" of "*string(TotalTimeSteps)))
                    Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Flows_"*TimeStamp*".png")
                
                    # Plot the battery charge:
                    Plots.plot(value.(m_outagesimulator[Symbol("BatteryCharge_"*n)]), label = "Battery Charge")
                    Plots.xlabel!("Time Step")
                    Plots.ylabel!("Charge (kWh)")
                    display(Plots.title!("Node "*n*": Battery Charge, outage "*string(i)*" of "*string(TotalTimeSteps)))
                    Plots.savefig(Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Charge_"*TimeStamp*".png")
                
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

return OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived
end 

function Results_Compilation(results, Outage_Results, Microgrid_Settings, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; line_upgrade_results = "", transformer_upgrade_results = "")

    InputsList = Microgrid_Settings.REoptInputsList
    LineFromSubstationToFacilityMeter = Microgrid_Settings.Substation_Node * "-" * Microgrid_Settings.FacilityMeter_Node

    # Compute system-level outputs
    system_results = Dict{String, Float64}()
    
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
                                                                    (results[node_temp]["PV"]["year_one_energy_produced_kwh"] - sum(results[node_temp]["PV"]["electric_curtailed_series_kw"]/Microgrid_Settings.TimeStepsPerHour))
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

    # Generate a csv file with outputs from the model if the "Generate_CSV_of_outputs" field is set to true
    if Microgrid_Settings.Generate_CSV_of_outputs == true
        @info "Generating CSV of outputs"
        DataLabels = []
        Data = []
        
        if Microgrid_Settings.Model_Type == "PowerModelsDistribution"
            MaximumPowerOnSubstationLine = "TBD"
            MinimumPowerOnSubstationLine = "TBD"
            AveragePowerOnSubstationLine = "TBD"
        elseif Microgrid_Settings.Model_Type == "BasicLinear"
            MaximumPowerOnSubstationLine = (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
            MinimumPowerOnSubstationLine = (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
            AveragePowerOnSubstationLine = (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
        end

        # Add system-level results
        push!(DataLabels, "----System Results----")
        push!(Data,"")

        push!(DataLabels,"  Total Lifecycle Cost (LCC)")
        push!(Data, round(system_results["total_lifecycle_cost"], digits=0))
        push!(DataLabels,"  Total Lifecycle Capital Cost (LCCC)")
        push!(Data, round(system_results["total_lifecycle_capital_cost"], digits=0))

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

        push!(DataLabels,"  Maximum power flow on substation line")
        push!(Data, MaximumPowerOnSubstationLine)
        push!(DataLabels,"  Minimum power flow on substation line")
        push!(Data, MinimumPowerOnSubstationLine)
        push!(DataLabels,"  Average power flow on substation line")
        push!(Data, AveragePowerOnSubstationLine)

        # Add the microgrid outage results to the dataframe
        push!(DataLabels, "----Microgrid Outage Results----")
        push!(Data, "")
        if Microgrid_Settings.RunOutageSimulator == true
            for i in 1:length(Microgrid_Settings.LengthOfOutages_timesteps)
                OutageLength = Microgrid_Settings.LengthOfOutages_timesteps[i]
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
        CSV.write(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/Results_Summary_"*TimeStamp*".csv", dataframe_results)
        
        # Save the Line Flow summary for each line to a different csv
        #CSV.write(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/Results_Line_Flow_Summary_"*TimeStamp*".csv", DataFrame_LineFlow_Summary)
        
        # Save line upgrade results to a csv 
        if Microgrid_Settings.Model_Line_Upgrades
            CSV.write(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/Results_Line_Upgrade_Summary_"*TimeStamp*".csv", dataframe_line_upgrade_summary)
        end

        # Save the transformer upgrade results to a csv
        if Microgrid_Settings.Model_Transformer_Upgrades
            CSV.write(Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/Results_Transformer_Upgrade_Summary_"*TimeStamp*".csv", dataframe_transformer_upgrade_summary)
        end
    end 

    #Display results if the "Display_Results" input is set to true
    if Microgrid_Settings.Display_Results == true
        print("\n-----")
        print("\nResults:") 
        print("\n   The computation time was: "*string(ComputationTime_EntireModel))
    
        print("Line Flow Results")
        display(DataFrame_LineFlow_Summary)
    
        print("\nSubstation data: ")
        print("\n   Maximum power flow from substation: "*string(MaximumPowerOnSubstationLine))
        print("\n   Minimum power flow from substation: "*string(MinimumPowerOnSubstationLine))
        print("\n   Average power flow from substation: "*string(AveragePowerOnSubstationLine))
    
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

    return system_results    
end


function CreateResultsMap(results, Microgrid_Inputs, TimeStamp)

    lines = keys(results["FromREopt_Dictionary_LineFlow_Power_Series"])

    # Extract the latitude and longitude for the busses
    bus_coordinates_filename = Microgrid_Inputs.Bus_Coordinates
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
                if i*"-"*x in lines
                    line_cords[i*"-"*x] = [bus_cords[i],bus_cords[x]]
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
    PlotlyJS.savefig(p, Microgrid_Inputs.FolderLocation*"/results_"*TimeStamp*"/Results_and_Layout.html")
    display(p)

end

# Function to create additional plots using PlotlyJS
function Aggregated_PowerFlows_Plot(results, TimeStamp, Microgrid_Inputs)
    # Additonal plotting using PlotlyJS

        OutageStartTimeStep = Microgrid_Inputs.SingleOutageStartTimeStep
        OutageStopTimeStep = Microgrid_Inputs.SingleOutageStopTimeStep
        
        #NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"])) 

        NodeList = []
        for i in Microgrid_Inputs["REoptInputsList"]
            push!(NodeList, i["Site"]["node"])
        end

        TotalLoad_series = zeros(8760) # initiate the total load as 0
        for n in NodeList
            #NodeNum = parse(Int,n)
            TotalLoad_series = TotalLoad_series + results["REopt_results"][n]["ElectricLoad"]["load_series_kw"] 
        end
    
        # determine all of the nodes with PV and determine total PV output across the entire network
        NodesWithPV = []
        for i in keys(results["REopt_results"])
            if "PV" in keys(results["REopt_results"][i])
                push!(NodesWithPV, i)
            end
        end
        PVOutput = zeros(8760)
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
        BatteryOutput = zeros(8760)
        for NodeNumberTemp in NodesWithBattery
            if results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["size_kw"] > 0  # include this if statement to prevent trying to add in empty electric storage time series vectors
                BatteryOutput = BatteryOutput + results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"] + results["REopt_results"][NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"] 
            end
        end
    
        # determine all of the nodes with generator
        NodesWithGenerator = []
        for i in keys(results["REopt_results"])
            if "Generator" in keys(results["REopt_results"][i])
                push!(NodesWithBattery, i)
            end
        end
        GeneratorOutput = zeros(8760)
        for NodeNumberTemp in NodesWithGenerator
            GeneratorOutput = GeneratorOutput + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_load_series_kw"] + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"] + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_storage_series_kw"] 
        end
    
        #Plot the network-wide power use 

        # Static plot
        days = collect(1:8760)/24
        Plots.plot(days, TotalLoad_series, label="Total Load")
        Plots.plot!(days, PVOutput, label="Combined PV Output")
        Plots.plot!(days, BatteryOutput, label = "Combined Battery Output")
        Plots.plot!(days, GeneratorOutput, label = "Combined Generator Output")
        Plots.plot!(days, results["FromREopt_Dictionary_LineFlow_Power_Series"]["0-15"]["NetRealLineFlow"])
        display(Plots.title!("System Wide Power Demand and Generation"))
               
        if (OutageStopTimeStep - OutageStartTimeStep) > 0
            OutageStart_Line = OutageStartTimeStep/24
            OutageStop_Line = OutageStopTimeStep/24
            Plots.plot!([OutageStart_Line, OutageStart_Line],[0,maximum(TotalLoad_series)], label= "Outage Start")
            Plots.plot!([OutageStop_Line, OutageStop_Line],[0,maximum(TotalLoad_series)], label= "Outage End")
        end
        
        # Interactive plot using PlotlyJS
        traces = PlotlyJS.GenericTrace[]
        layout = PlotlyJS.Layout(title_text = "System Wide Power Demand and Generation", xaxis_title_text = "Day", yaxis_title_text = "Power (kW)")
        
        push!(traces, PlotlyJS.scatter(name = "Total load", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
            x = days,
            y = TotalLoad_series
        ))
        push!(traces, PlotlyJS.scatter(name = "Combined PV Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
            x = days,
            y = PVOutput
        ))
        push!(traces, PlotlyJS.scatter(name = "Combined Battery Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
            x = days,
            y = BatteryOutput
        ))
        push!(traces, PlotlyJS.scatter(name = "Combined Generator Output", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
            x = days,
            y = GeneratorOutput
        ))    
        push!(traces, PlotlyJS.scatter(name = "Power from Substation", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
            x = days,
            y = results["FromREopt_Dictionary_LineFlow_Power_Series"]["0-15"]["NetRealLineFlow"]
        ))  
        
        if (OutageStopTimeStep - OutageStartTimeStep) > 0
            OutageStart_Line = OutageStartTimeStep/24
            OutageStop_Line = OutageStopTimeStep/24
            push!(traces, PlotlyJS.scatter(name = "Outage Start", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
                x = [OutageStart_Line, OutageStart_Line],
                y = [0,maximum(TotalLoad_series)]
            ))  
            push!(traces, PlotlyJS.scatter(name = "Outage End", showlegend = true, fill = "none", line = PlotlyJS.attr(width = 3),
                x = [OutageStop_Line, OutageStop_Line],
                y = [0,maximum(TotalLoad_series)]
            ))  
        end

        p = PlotlyJS.plot(traces, layout)
        display(p)
        PlotlyJS.savefig(p, Microgrid_Settings.FolderLocation*"/results_"*TimeStamp*"/CombinedResults_PowerOutput_interactiveplot.html")
    end



# Function to check for errors in the data inputs for the model
function RunDataChecks(Microgrid_Settings,  REopt_dictionary; ldf_inputs_dictionary="")

    ps = REopt_dictionary
    
    for p in ps
        node_temp = p.s.site.node

        if p.s.settings.facilitymeter_node != Microgrid_Settings.FacilityMeter_Node
            throw(@error("The facilitymeter_node input for each REopt node must equal the FacilityMeter_Node defined in the microgrid settings, which is $(FacilityMeter_Node)"))
        end

        if p.s.settings.time_steps_per_hour != Microgrid_Settings.TimeStepsPerHour
            throw(@error("The time steps per hour for each REopt node must match the time steps per hour defined in the microgrid settings dictionary"))
        end
        
        if Microgrid_Settings.Critical_Load_Method == "Fraction"
            if string(p.s.site.node) ∉ keys(Microgrid_Settings.Critical_Load_Fraction)
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load fraction in the Critical_Load_Fraction input dictionary"))
                end
            end
        end

        if Microgrid_Settings.Critical_Load_Method == "TimeSeries"
            if string(p.s.site.node) ∉ keys(Microgrid_Settings.Critical_Load_TimeSeries)
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load timeseries profile in the Critical_Load_TimeSeries input dictionary"))
                end
            end
        end
        # TODO: add data check to ensure that if a critical load method is defined, then there must be either a critical load fraction or a critical load timeseries dictionary   
        
        if Int(length(p.s.electric_load.loads_kw)) != Int(8760 * Microgrid_Settings.TimeStepsPerHour)
            throw(@error("At REopt node $(node_temp), the length of the electric loads vector does not correlate with the time steps per hour defined in the Microgrid_Settings dictionary"))
        end

        if Microgrid_Settings.Model_Type == "BasicLinear"
            if p.s.settings.time_steps_per_hour != Int(ldf_inputs_dictionary["T"]/8760)
                throw(@error("The number of time steps in the ldf_inputs_dictionary must correlate to the time_steps_per_hour in all REopt nodes"))
            end
            if string(p.s.site.node) ∉ keys(ldf_inputs_dictionary["load_nodes"]) #  ∉ is the "not in" symbol
                throw(@error("The REopt node $(node_temp) is not in the list of nodes in the ldf_inputs_dictionary"))
            end
        end

    end
    
    if Microgrid_Settings.Model_Type == "BasicLinear"
        if ldf_inputs_dictionary["v0_input"] > ldf_inputs_dictionary["v_uplim_input"]
            throw(@error("In the ldf_inputs_dictionary, the v0_input value must be less than the v_uplim_input value"))
        end 
        if ldf_inputs_dictionary["v0_input"] < ldf_inputs_dictionary["v_lolim_input"]
            throw(@error("In the ldf_inputs_dictionary, the v0_input value must be greater than the v_lolim_input value"))
        end   
    end

    if Microgrid_Settings.MicrogridType ∉ ["CommunityDistrict", "BehindTheMeter", "OffGrid"]
        throw(@error("An invalid microgrid type was provided in the inputs"))
    end

    if Microgrid_Settings.MicrogridType != "CommunityDistrict"
        @warn("For the community district microgrid type, the electricity tariff for the facility meter node should be 0")
    end

    if Microgrid_Settings.Generate_Results_Plots == true
        for i in Microgrid_Settings.RunNumbersForPlottingOutageSimulatorResults
            if i > Microgrid_Settings.NumberOfOutagesToEvaluate
                throw(@error("In the Microgrid_Settings dictionary, all values for the RunNumbersForPlottingOutageSimulatorResults must be less than the NumberOfOutagesToEvaluate"))
            end
        end
    end

    if Microgrid_Settings.Critical_Load_Method == "Fraction"
        for x in values(Microgrid_Settings.Critical_Load_Fraction)
            if x >= 5.0
                throw(@error("The Critical_Load_Fraction load fraction should be entered as a fraction, not a percent. The model currently limits the Critical_Load_Fraction to 5.0 (or 500%) to reduce possibility of user error. "))
            end
        end
    end

    if Microgrid_Settings.SingleOutageStartTimeStep > Microgrid_Settings.SingleOutageStopTimeStep
        throw(@error("In the Microgrid_Settings dictionary, the single outage start time must be a smaller value than the single outage stop time"))
    end

    if Microgrid_Settings.SingleOutageStopTimeStep > (8760 * Microgrid_Settings.TimeStepsPerHour)
        TotalNumberOfTimeSteps = Int(8760 * Microgrid_Settings.TimeStepsPerHour)
        throw(@error("In the Microgrid_Settings dictionary, the defined outage stop time must be less than the total number of time steps, which is $(TotalNumberOfTimeSteps)"))
    end
end