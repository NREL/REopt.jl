#=
# Code for running the REopt microgrid analysis capability
=# 


# The main function to run all parts of the model (the optimization, the outage simulator, and the OpenDSS post-processor)
function Microgrid_Model(JuMP_Model, Microgrid_Settings, ldf_inputs_dictionary)
    # This function accepts three inputs:
        # 1. The JuMP model
        # 2. The Microgrid_Inputs
        # 3. network_inputs_dictionary
         

    StartTime_EntireModel = now() # record the start time for the computation
    cd(Microgrid_Settings["FolderLocation"])

    # Create a folder for the outputs if saving results
    TimeStamp = Dates.format(now(), "mm-dd-yyyy")*"_"*Dates.format(now(), "HH-MM")
    if Microgrid_Settings["Generate_CSV_of_outputs"] == true || Microgrid_Settings["Generate_Results_Plots"] == true
        @info "Creating a folder for the results"
        mkdir(Microgrid_Settings["FolderLocation"]*"/results_"*TimeStamp)
    end
    if Microgrid_Settings["Generate_Results_Plots"] == true
        mkdir(Microgrid_Settings["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots") 
    end

    # Prepare the electric loads
    REopt_inputs_all_nodes = Microgrid_Settings["REoptInputsList"]

    # Prepare loads for using with the outage simulator, if the fraction method is used for determining the critical load
    if  Microgrid_Settings["Critical_Load_Method"] == "Fraction"
        load_profiles_for_outage_sim_if_using_the_fraction_method = Dict([])
        for REopt_inputs in REopt_inputs_all_nodes
            load_profiles_for_outage_sim_if_using_the_fraction_method[REopt_inputs["Site"]["node"]] = deepcopy( REopt_inputs["ElectricLoad"]["loads_kw"] )
        end
        Microgrid_Settings["load_profiles_for_outage_sim_if_using_the_fraction_method"] = load_profiles_for_outage_sim_if_using_the_fraction_method
    else
        Microgrid_Settings["load_profiles_for_outage_sim_if_using_the_fraction_method"] = ""
    end

    # If outages are defined in the optimization, set the loads to the critical loads during the outages
    if Microgrid_Settings["SingleOutageStopTimeStep"] - Microgrid_Settings["SingleOutageStartTimeStep"] > 0
        
        OutageStart = Microgrid_Settings["SingleOutageStartTimeStep"]
        OutageEnd = Microgrid_Settings["SingleOutageStopTimeStep"]

        for i in 1:length(Microgrid_Settings["REoptInputsList"])
            
            node = Microgrid_Settings["REoptInputsList"][i]["Site"]["node"]

            if Microgrid_Settings["Critical_Load_Method"] == "Fraction"
                if sum(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"]) > 0 # only apply the critical load fraction if there is a load on the node
                    load_segment_initial = deepcopy(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = 0.75 * load_segment_initial[OutageStart:OutageEnd]                    
                    delete!(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"],"loads_kw")
                    Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end 
            elseif Microgrid_Settings["Critical_Load_Method"] == "TimeSeries"
                if sum(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"]) > 0 
                    load_segment_initial = deepcopy(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"])
                    load_segment_modified = deepcopy(load_segment_initial)
                    load_segment_modified[OutageStart:OutageEnd] = Microgrid_Settings["Critical_Load_TimeSeries"][string(node)][OutageStart:OutageEnd]                    
                    delete!(Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"],"loads_kw")
                    Microgrid_Settings["REoptInputsList"][i]["ElectricLoad"]["loads_kw"] = load_segment_modified
                end
            end
        end
    end     
    
    # Generate the scenarios, REoptInputs, and list of REoptInputs
    scenarios = Dict([])
    for i in 1:length(Microgrid_Settings["REoptInputsList"])
        scenarios[i] = Scenario(Microgrid_Settings["REoptInputsList"][i])
    end

    REoptInputs_dictionary = Dict([])
    for i in 1:length(Microgrid_Settings["REoptInputsList"])
        REoptInputs_dictionary[i] = REoptInputs(scenarios[i])
    end

    REopt_dictionary = [REoptInputs_dictionary[1]]
    for i in 2:length(Microgrid_Settings["REoptInputsList"])
        push!(REopt_dictionary, REoptInputs_dictionary[i])
    end
    
    # Run function to check for errors in the model inputs
    RunDataChecks(Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary)

    # Run the optimization:
    DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results, DataFrame_LineFlow_Summary, LineNominalVoltages_Summary, BusNominalVoltages_Summary, model = Microgrid_REopt_Model(JuMP_Model, Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary, TimeStamp) # ps_B, TimeStamp) #
  
    # Run the outage simulator if "RunOutageSimulator" is set to true
    if Microgrid_Settings["RunOutageSimulator"] == true
        OutageLengths = Microgrid_Settings["LengthOfOutages_timesteps"] 
        TimeStepsPerHour = Microgrid_Settings["TimeStepsPerHour"] 
        NumberOfOutagesToTest = Microgrid_Settings["NumberOfOutagesToEvaluate"]
        Outage_Results = Dict([])
        for i in 1:length(OutageLengths)
            OutageLength = OutageLengths[i]
            OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived = Microgrid_OutageSimulator(JuMP_Model, DataDictionaryForEachNode, REopt_dictionary, Microgrid_Settings, TimeStamp; NumberOfOutagesToTest = NumberOfOutagesToTest, ldf_inputs_dictionary = ldf_inputs_dictionary, TimeStepsPerHour_input = TimeStepsPerHour, OutageLength_TimeSteps_Input = OutageLength)
            Outage_Results["$(OutageLength_TimeSteps)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, "NumberOfRuns" => RunNumber, "NumberOfOutagesSurvived" => SuccessfullySolved ])
        end 
    else
        print("\n  Not running the microgrid outage simulator in this model")
        Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
    end 

    # TODO: configure OpenDSS to run as an islanded microgrid during the defined outage
    if Microgrid_Settings["RunOpenDSS"] == true
        OpenDSSResults = RunOpenDSS(results, Microgrid_Settings)
    else
        OpenDSSResults = "OpenDSS Not Run" 
    end
    
    EndTime_EntireModel = now()
    ComputationTime_EntireModel = EndTime_EntireModel - StartTime_EntireModel

    # Results processing and generation of outputs:
    system_results = Results_Processing(results, Outage_Results, OpenDSSResults, Microgrid_Settings, ldf_inputs_dictionary, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel)

    # Compile output data into a dictionary to return from the dictionary
    CompiledResults = Dict([("System_Results", system_results),
                            ("DataDictionaryForEachNode", DataDictionaryForEachNode), 
                            ("FromREopt_Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                            ("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series), 
                            ("ldf_inputs", ldf_inputs),
                            ("REopt_results", results),
                            ("Outage_Results", Outage_Results),
                            ("DataFrame_LineFlow_Summary", DataFrame_LineFlow_Summary),
                            ("OpenDSSResults", OpenDSSResults),
                            ("LineNominalVoltages_Summary", LineNominalVoltages_Summary), 
                            ("BusNominalVoltages_Summary", BusNominalVoltages_Summary),
                            ("ComputationTime_EntireModel", ComputationTime_EntireModel)
                            ])
    return CompiledResults, model  
end

# Function to run the REopt analysis 
function Microgrid_REopt_Model(JuMP_Model, Microgrid_Inputs, ldf_inputs_dictionary, REoptInputs, TimeStamp)
    cd(Microgrid_Inputs["FolderLocation"])
    ldf_inputs_dictionary = ldf_inputs_dictionary
    ps = REoptInputs
    
    StartTime = now() #Recording the start time
    NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"])) 

    FacilityMeter_Node = Microgrid_Inputs["FacilityMeter_Node"] 
    MicrogridType = Microgrid_Inputs["MicrogridType"]
    AllowExportBeyondSubstation = Microgrid_Inputs["AllowExportBeyondSubstation"]
    SubstationExportLimit = Microgrid_Inputs["SubstationExportLimit"]
    GeneratorFuelGallonAvailable = Microgrid_Inputs["GeneratorFuelGallonAvailable"]
    OutageStartTimeStep = Microgrid_Inputs["SingleOutageStartTimeStep"]
    OutageStopTimeStep = Microgrid_Inputs["SingleOutageStopTimeStep"]

    TimeSteps = collect(1:(8760*Microgrid_Inputs["TimeStepsPerHour"]))

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
LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Inputs["FacilityMeter_Node"]
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
if Microgrid_Inputs["Model_Switches"] == true 
    for i in keys(Microgrid_Inputs["Switch_Open_Timesteps"])
        Switch_Open_Timesteps = Microgrid_Inputs["Switch_Open_Timesteps"][i]
        @constraint(m, [t in Switch_Open_Timesteps], m[:Pᵢⱼ][i,t] == 0 )
    end
end

# Constraints 6: For power export to the grid
for p in ps
    if string(p.s.site.node) == p.s.settings.facilitymeter_node
        @info "Setting facility-level grid purchase to the power flow on line "*string("0-", FacilityMeter_Node)*", using the variable: "*string(" dvGridPurchase_", FacilityMeter_Node)
                
        if Microgrid_Inputs["AllowExportBeyondSubstation"] == true
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
                sum(m[Symbol("dvGridPurchase_"*FacilityMeter_Node)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) <= Microgrid_Inputs["SubstationImportLimit"] * binSubstationPositivePowerFlow[ts]
            )   
            @constraint(m, [ts in p.time_steps],
                sum(m[Symbol("dvProductionToGrid_"*FacilityMeter_Node)]["PV", u, ts] for u in p.export_bins_by_tech["PV"]) <= Microgrid_Inputs["SubstationExportLimit"] * (1 - binSubstationPositivePowerFlow[ts])
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

# Note: the objective accounts for costs of all REopt nodes input into the model
@objective(m, Min, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in ps) )

@info "The optimization is starting"
set_optimizer_attribute(m, "MIPRELSTOP", 0.02) 
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
DataFrame_LineFlow = DataFrame(["empty" 0 0 0 0 0 0], [:LineCode, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Power_kW_At_Nominal_Voltage])
Dictionary_LineFlow_Power_Series = Dict([])

#for edge in edges
  
for j in ldf_inputs.busses
    for i in i_to_j(j, ldf_inputs)
    edge = string(i*"-"*j)
    #edge_underscore = string(i*"_"*j)

    NetRealLineFlow = (value.(m[:Pᵢⱼ][edge,:]).data* ldf_inputs.Sbase)/1000 
    NetReactiveLineFlow = (value.(m[:Qᵢⱼ][edge,:]).data*ldf_inputs.Sbase)/1000 

    linenormamps = get_ijlinenormamps(i,j,ldf_inputs)
    LineNominalVoltage = parse(Float64,LineNominalVoltages_Summary[edge])
    MaximumPower_AtNominalVoltage_kW = 0.001*linenormamps*LineNominalVoltage

    DataLineFlow[1] = round(minimum(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[2] = round(maximum(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[3] = round(mean(NetRealLineFlow[:]), digits = 5)
    DataLineFlow[4] = linenormamps
    DataLineFlow[5] = LineNominalVoltage
    DataLineFlow[6] = round(MaximumPower_AtNominalVoltage_kW, digits=0)

    DataFrame_LineFlow_temp = DataFrame([("Line "*string(edge)) DataLineFlow[1] DataLineFlow[2] DataLineFlow[3] DataLineFlow[4] DataLineFlow[5] DataLineFlow[6]], [:LineCode, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Power_kW_At_Nominal_Voltage])
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
if Microgrid_Inputs["Generate_Results_Plots"] == true
    @info "Generating results plots"
    mkdir(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Voltage_at_Each_Node_Plots") 
    # Plot showing that the voltage is within defined +/- percentage of the nominal voltage
    for n in NodeList
        Plots.plot(Dictionary_Node_Data_Series[n]["VoltageMagnitude_kV"], label = "Voltage Magnitude (kV)", linewidth = 2, line = (:dash), size = (1000,400))
        Plots.plot!(parse(Float64,BusNominalVoltages_Summary[n])*v_uplim_input*(ones(length(TimeSteps))/1000), label = "Upper limit (kV)")
        Plots.plot!(parse(Float64,BusNominalVoltages_Summary[n])*v_lolim_input*(ones(length(TimeSteps))/1000), label = "Lower limit (kV)")
        Plots.xlabel!("Hour of the Year") 
        Plots.ylabel!("Voltage (kV)")
        #Plots.xlims!(4000,4100)
        display(Plots.title!("Node "*n*": Voltage"))
        Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Voltage_at_Each_Node_Plots/Node_$(n)_Voltage"*TimeStamp*".png")
    end 

    # Plot, for a defined time, how the per-unit voltage is changing through the system
        # Note: use per-unit so can track voltage drop through lines that have different nominal voltages
    if Microgrid_Inputs["PlotVoltageDrop"] == true
        NodesToPlot = Microgrid_Inputs["PlotVoltageDrop_NodeNumbers"]
        timestep_voltage = Microgrid_Inputs["PlotVoltageDrop_VoltageTimeStep"]
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

    # Plot the real power load and real power injection data for each REopt node:
    mkdir(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Power_Flow_at_Each_Node")
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
        display(Plots.xlims!(Microgrid_Inputs["ResultPlotsStartTimeStep"],Microgrid_Inputs["ResultPlotsEndTimeStep"]))

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
        Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Power_Flow_at_Each_Node/Node_$(n)_PowerFlows"*TimeStamp*".png")
    end

    # Plot all of the real and reactive power flow through each distribution line
    mkdir(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Power_Flow_through_Each_Line")
    for edge in edges
        Plots.plot(Dictionary_LineFlow_Power_Series[edge]["NetRealLineFlow"], label = "Real Power Flow" )
        Plots.plot!(Dictionary_LineFlow_Power_Series[edge]["NetReactiveLineFlow"], label = "Reactive Power Flow" )
        Plots.xlabel!("Hour of the Year")
        Plots.ylabel!("Power (kW)")
        Plots.title!("Distribution Line $(edge): Power Flow")
        display(Plots.xlims!(Microgrid_Inputs["ResultPlotsStartTimeStep"],Microgrid_Inputs["ResultPlotsEndTimeStep"]))
        Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Power_Flow_through_Each_Line/Line_$(edge)_PowerFlows"*TimeStamp*".png")
    end
end 

# Building the input dictionary for the microgrid outage simulator:
if Microgrid_Inputs["RunOutageSimulator"] == true

    # Define the critical loads
    critical_loads_kw = Dict([])
    if Microgrid_Inputs["Critical_Load_Method"] == "Fraction"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs["Critical_Load_Fraction"][NodeList[i]] * Microgrid_Inputs["load_profiles_for_outage_sim_if_using_the_fraction_method"][parse(Int,NodeList[i])]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs["TimeStepsPerHour"])
            end
        end
    elseif Microgrid_Inputs["Critical_Load_Method"] == "TimeSeries"
        for i in 1:length(NodeList)
            if results[parse(Int,NodeList[i])]["ElectricLoad"]["annual_calculated_kwh"] > 1
                critical_loads_kw[NodeList[i]] = Microgrid_Inputs["Critical_Load_TimeSeries"][NodeList[i]]
            else
                critical_loads_kw[NodeList[i]] = zeros(8760*Microgrid_Inputs["TimeStepsPerHour"])
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
        if NodeList[1] in keys(Microgrid_Inputs["GeneratorFuelGallonAvailable"])
            GeneratorFuelGallonAvailable = Microgrid_Inputs["GeneratorFuelGallonAvailable"][NodeList[1]]
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
            if NodeList[i] in keys(Microgrid_Inputs["GeneratorFuelGallonAvailable"])
                GeneratorFuelGallonAvailable = Microgrid_Inputs["GeneratorFuelGallonAvailable"][NodeList[i]]
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

else
    @info "Not running the outage simulator"
    DataDictionaryForEachNode = "The outage simulator was not used"
end

return DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results, DataFrame_LineFlow, LineNominalVoltages_Summary, BusNominalVoltages_Summary, m
end 


# Use the function below to run the outage simulator 
function Microgrid_OutageSimulator(JuMP_Model, DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp; NumberOfOutagesToTest = 15, ldf_inputs_dictionary = ldf_inputs_dictionary, TimeStepsPerHour_input = 1, OutageLength_TimeSteps_Input = 1)

NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"]))

OutageLength_TimeSteps = OutageLength_TimeSteps_Input 
MaximumTimeStepToEvaluate_limit = ldf_inputs_dictionary["T"]-(OutageLength_TimeSteps+1) # T is the number of timesteps

if MaximumTimeStepToEvaluate_limit < NumberOfOutagesToTest
    @warn "The number of possible outages to test is less than the number of outages requested by the user. $(MaximumTimeStepToEvaluate) will be evaluated instead of $(NumberOfOutagesToTest)."
    MaximumTimeStepToEvaluate = MaximumTimeStepToEvaluate_limit
else
    MaximumTimeStepToEvaluate = NumberOfOutagesToTest
end

RunNumber = 0
SuccessfullySolved = 0
    @info "Number of outages to evaluate: "*string(MaximumTimeStepToEvaluate)

OutageSimulator_LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Inputs["FacilityMeter_Node"]

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

# Define the outage start time steps based on the number of outages
IncrementSize_ForOutageStartTimes = Int(floor(MaximumTimeStepToEvaluate_limit/NumberOfOutagesToTest))
RunsTested = 0
index = 0
for x in 1:MaximumTimeStepToEvaluate
    print("\n Outage Simulation Run # "*string(x)*"  of  "*string(MaximumTimeStepToEvaluate)*" runs")
    RunsTested = RunsTested + 1
    i = Int(x*IncrementSize_ForOutageStartTimes)
    TotalTimeSteps = 8760*Microgrid_Inputs["TimeStepsPerHour"]
    empty!(JuMP_Model) # empties the JuMP model so that the same variables names can be applied in the new model
    m_outagesimulator = JuMP_Model

    # Generate the power flow constraints
    power_flow_add_variables(m_outagesimulator, ldf_inputs_new)
    constrain_power_balance(m_outagesimulator, ldf_inputs_new)
    constrain_substation_voltage(m_outagesimulator, ldf_inputs_new)
    constrain_KVL(m_outagesimulator, ldf_inputs_new)
    constrain_bounds(m_outagesimulator, ldf_inputs_new)
  
    for n in NodeList
        GenPowerRating = DataDictionaryForEachNode[n]["GeneratorSize"]  
        TimeSteps = OutageLength_TimeSteps
        TimeStepsPerHour = TimeStepsPerHour_input
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
        
    # Constrain the loads
    constrain_loads(m_outagesimulator, ldf_inputs_new, REopt_dictionary) 
    
    # Prevent power from entering the microgrid (to represent a power outage)
    JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ][OutageSimulator_LineFromSubstationToFacilityMeter,t] .>= 0 ) 
    JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ][OutageSimulator_LineFromSubstationToFacilityMeter,t] .<= 0.001)

    # Determine all of the nodes with PV
    NodesWithPV = []
    for p in NodeList 
        if maximum(DataDictionaryForEachNode[p]["PVproductionprofile"]) > 0
            push!(NodesWithPV, p)
        end
    end 

    # Objective function, which is formulated to maximize the PV power that is used to meet the load
    @objective(m_outagesimulator, Max, sum(sum(m_outagesimulator[Symbol(string("dvPVToLoad_", n))]) for n in NodesWithPV))
   
    runresults = optimize!(m_outagesimulator)
    print("\n The result from run #"*string(RunsTested)*" is: "*string(termination_status(m_outagesimulator)))

    if string(termination_status(m_outagesimulator)) == "OPTIMAL"
        SuccessfullySolved = SuccessfullySolved + 1

        # TODO: change the calculation of the fuel remaining so it automatically calculates the fuel left on nodes with generators
        #print("\n the fuel left is: "*string(value.(m_outagesimulator[Symbol("FuelLeft_3")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_4")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_6")]) +
        #value.(m_outagesimulator[Symbol("FuelLeft_10")])) * " gal")
                
        if Microgrid_Inputs["Generate_Results_Plots"] == true
            @info "Generating results plots from the outage simulator, if the defined run numbers for creating plots survived the outage"

            # Generate plots for the outage simulator run numbers defined in the Microgrid_Inputs dictionary 
            if x in Microgrid_Inputs["RunNumbersForPlottingOutageSimulatorResults"]
                mkdir(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)")
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
                    Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Load_Balance_"*TimeStamp*".png")
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
                    Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Power_Export_"*TimeStamp*".png")
                
                    # Plot the battery flows
                    Plots.plot(-value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load")
                    Plots.plot!(-value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToBat_"*n)]), label = "Grid to Battery")
                    Plots.plot!(value.(m_outagesimulator[Symbol("dvPVToBat_"*n)]), label = "PV to Battery")
                    Plots.xlabel!("Time Step")
                    Plots.ylabel!("Power (kW)")
                    display(Plots.title!("Node "*n*": Battery Flows, outage "*string(i)*" of "*string(TotalTimeSteps)))
                    Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Flows_"*TimeStamp*".png")
                
                    # Plot the battery charge:
                    Plots.plot(value.(m_outagesimulator[Symbol("BatteryCharge_"*n)]), label = "Battery Charge")
                    Plots.xlabel!("Time Step")
                    Plots.ylabel!("Charge (kWh)")
                    display(Plots.title!("Node "*n*": Battery Charge, outage "*string(i)*" of "*string(TotalTimeSteps)))
                    Plots.savefig(Microgrid_Inputs["FolderLocation"]*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Charge_"*TimeStamp*".png")
                
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


# Function to run OpenDSS as a post processor for the data
    # NOTE: this function is still in development
    # This function only works with hourly interval data currently
function RunOpenDSS(REoptresults, Microgrid_Inputs)
    #using OpenDSSDirect # TODO: add OpenDSSDirect to the REopt dependencies and REopt.jl file
    #REoptresults = results 
    # Step 1: Save the power flows for each node into a csv file
    cd(Microgrid_Inputs["FolderLocation"])
    # Step 2: Initiate the OpenDSS model
    dss("""
        Clearall
        Clear
        New object=circuit.NewCircuit basekv = 22.7 bus1 = 0.1 pu=1.00 phases=1
        """)
    # TODO: change the basekv to be defined by the substation voltage defined in the REopt model

    # Step 3: bring the existing line and linecodes files into the model
    
    dss("redirect Scenario1A_linecodes.dss")    
    dss("redirect Scenario1A_lines.dss") 
        
     #   dss("""redirect Scenario1A_transformers.dss""")
     

    # Step 2: generate load shapes for each power profile
    #REoptresults = results

    LoadShapes = Dict([])

    # because the kw will be set to 1 when defining the loads at each bus, the loadshape can just be in units of kW
    KeyList = [i for i in keys(REoptresults)]
    # use a for loop to generate a loadshape, load, and monitor for each bus, based on the results for each node in the REopt results
    for i in 1:length(KeyList)
        NodeNumber = KeyList[i]

        # Step 1: Define the load shapes
        TotalLoad_temp = REoptresults[NodeNumber]["ElectricLoad"]["load_series_kw"]
        TotalLoad_temp_string = chop(string(TotalLoad_temp), head = 4, tail = 0)   # use the chop to eliminate the "Real" type of the vector in the string
        #LoadShapes_temp = Dict([ ["Node"*string(NodeNumber)] => TotalLoad_temp]) # - TotalPVGeneration_temp - Battery_dischargeandexport_temp ]) # note: the loadshape will be negative if PV is exporting, this will signal to OpenDSS that the node is exporting power
        
        dss("new Loadshape.Node$(NodeNumber)LoadShape npts=8760 interval=1  mult= $(TotalLoad_temp_string)  ") #(2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2)") #  (file=../LoadShapes/Node1_loadshape.csv")
        
        # Define the load at each bus, using the load shape defined above
        # TODO: update the kv in the load definition
        dss("new load.Node$(NodeNumber)REopt  conn=Delta bus1=$(NodeNumber).1  kv = 22.7  kw = 1 pf = 0.99  phases = 1  yearly =Node$(NodeNumber)LoadShape") # yearly = Node1LoadShape")
        # Add a monitor to the load
        dss("New monitor.monitor_Node$(NodeNumber) element=load.Node$(NodeNumber)REopt terminal=1 mode=0")

        # Step 2: Define the PV generation profile
        # Compute the PV production shape
        if "PV" in keys(REoptresults[NodeNumber])
            if REoptresults[NodeNumber]["PV"]["size_kw"] > 0
                TotalPVGeneration_temp = REoptresults[NodeNumber]["PV"]["electric_to_grid_series_kw"] + 
                                        REoptresults[NodeNumber]["PV"]["electric_to_load_series_kw"] +
                                        REoptresults[NodeNumber]["PV"]["electric_to_storage_series_kw"] + 
                                        REoptresults[NodeNumber]["PV"]["electric_curtailed_series_kw"]
                PVGenerationLoadShape_temp = TotalPVGeneration_temp / REoptresults[NodeNumber]["PV"]["size_kw"]
                #print(PVGenerationLoadShape_temp)
                PVGenerationLoadShape = chop(string(PVGenerationLoadShape_temp), head = 0, tail = 0)
                
                PVkw = REoptresults[NodeNumber]["PV"]["size_kw"]

                # note can define an hourly interval as either minterval=60 or interval=1
                dss("new Loadshape.Node$(NodeNumber)PVLoadShape npts=8760 minterval=60  mult= $(PVGenerationLoadShape)  ")
                dss("New 'PVSystem.PVNode$(NodeNumber)' phases=1 bus1=$(NodeNumber).1 kV=22.7 kva=$(PVkw) pmpp=$(PVkw) yearly=Node$(NodeNumber)PVLoadShape ")
            else 
                TotalPVGeneration_temp = zeros(8760)
                PVGenerationLoadShape = string(TotalPVGeneration_temp)
            end
        else 
            TotalPVGeneration_temp = zeros(8760)
            PVGenerationLoadShape = string(TotalPVGeneration_temp)
        end

        
        #TODO: does the PVGenerationLoadShape have to be in the load shape variable type?
        #TODO: change the kV and kva based on REopt inputs
        #TODO: what is the pmpp?
        #dss("New 'PVSystem.PV$(NodeNumber)' phases=1 bus1=$(NodeNumber).1 kV=22.7 kva=2000 pmpp=2000 yearly=$(PVGenerationLoadShape) ")
        
        # Step 3: Define the battery

        # Compute the electric storage output
        if "ElectricStorage" in keys(REoptresults[NodeNumber]) 
            if REoptresults[NodeNumber]["ElectricStorage"]["size_kw"] > 0
                Battery_discharge_temp = REoptresults[NodeNumber]["ElectricStorage"]["storage_to_grid_series_kw"] +
                                                REoptresults[NodeNumber]["ElectricStorage"]["storage_to_load_series_kw"]
                Battery_SOC_percent = 100*REoptresults[NodeNumber]["ElectricStorage"]["soc_series_fraction"]
                if "PV" in keys(REoptresults[NodeNumber])
                    Battery_charge_temp = REoptresults[NodeNumber]["PV"]["electric_to_storage_series_kw"] +
                                      REoptresults[NodeNumber]["ElectricUtility"]["electric_to_storage_series_kw"]
                else
                    Battery_charge_temp = REoptresults[NodeNumber]["ElectricUtility"]["electric_to_storage_series_kw"]
                end
                
                BatteryLoadShape = (Battery_discharge_temp + -Battery_charge_temp)/REoptresults[NodeNumber]["ElectricStorage"]["size_kw"]
                
                Battery_kw = REoptresults[NodeNumber]["ElectricStorage"]["size_kw"]
                Battery_kwh = REoptresults[NodeNumber]["ElectricStorage"]["size_kwh"]

                dss("new Loadshape.Node$(NodeNumber)BatteryLoadShape npts=8760 interval=1  mult= $(BatteryLoadShape)  ")
                dss("New 'Storage.ElectricStorageNode$(NodeNumber)' phases=1 bus1=$(NodeNumber).1 kV=22.7 kva=$(Battery_kw) kWrated=$(Battery_kw) yearly=Node$(NodeNumber)BatteryLoadShape  kWhrated=$(Battery_kwh) %Stored=100 %reserve=20 %EffCharge=98.5 %EffDischarge=98.5") # conn=delta ")

            else 
                Battery_dischargeandexport_temp = zeros(8760)
                Battery_SOC_percent = zeros(8760)     
            end                       
        else
            Battery_dischargeandexport_temp = zeros(8760)
            Battery_SOC_percent = zeros(8760) 
        end
        # storage may need to have double quotes
        # TODO: storage % stored based on the REopt results
        # TODO: change the kV and kva based on REopt inputs
        #dss("New 'Storage.ElectricStorage$(NodeNumber)' phases=1 bus1=$(NodeNumber).1 kV=22.7 kva=2000 kWrated=2000  kWhrated=6000 %Stored=100 %reserve=20 %EffCharge=98.5 %EffDischarge=98.5") # conn=delta ")

        # Step 4: Define the generator



    end 
    
    #PVGenerationLoadShape = chop(string(0.95*ones(8760)), head = 0, tail = 0)
    #dss("new Loadshape.Node10PVLoadShape npts=8760 interval=1  mult= $(PVGenerationLoadShape)  ")
    #NodeNum = 10
    #dss("New 'PVSystem.PVNode$(NodeNum)' phases=1 bus1=10.1 kV=22.7 kva=2000 pmpp=2000 yearly=Node10PVLoadShape ")
    #dss("New 'Storage.ElectricStorageNode8' phases=1 bus1=8.1 kV=22.7 kva=500 kWrated=500  kWhrated=6000 %Stored=100 %reserve=20 %EffCharge=98.5 %EffDischarge=98.5") # conn=delta ")

    # Step 5: Define a grid-forming inverter; this is required if the distribution system is operating disconnected from the grid

    dss("New InvControl.GridFormingInverter DERList=[PVSystem.PVNode3 Storage.ElectricStorageNode7] mode=GFM")
    # Storage.ElectricStorageNode8 PVSystem.PVNode10

    # print some information to make sure the data was added to the OpenDSS model
    println("The Load Shapes defined are: ")
    println(OpenDSSDirect.LoadShape.AllNames())

    println("The Loads defined are: ")
    println(OpenDSSDirect.Loads.AllNames()) #AllNames) 

    println("")

    # Step 6: Add energy monitors to record the data 

    dss("New monitor.monitor_1 element=load.node5reopt terminal=1 mode=0")
    dss("New monitor.line_test element=line.1_5 terminal=1 mode=0")


    

    # Step 4: set additional key features in the OpenDSS model 
        # To solve just the first part of the yearly profile, can say "set number = 7" to, for instance, solve the first 7 hours
    # Solve the full year grid-connected
    dss("""
        Set voltagebases = (10)  !modify this for base voltages
        Calcvoltagebases 

        set mode = yearly
        set number = 8760  ! The number of increments
        set stepsize = 1h  ! The time step length

        solve
    """)

    # Powerflow analysis for a bunch of different outages throughout the year
    dss("""
        !Solve grid connected for a few hours

        set number=4069 
        solve
        
        ! Opens line 0_1 and solves 
        open line.0_1 terminal=1
        edit PVSystem.PVNode3 ControlMode=GFM ! make the PVSystem grid forming (aka the reference) for a couple of hours, can't pick up the storage 
        edit storage.ElectricStorageNode7 State = Discharging ControlMode = GFL !initially was GFL and Idling ! Enables the storage device (fully charged) to operate as grid forming inverter remains like that for 6 hours
        set number=1
        solve
        
        ! Make the storage and/or PV the reference again 
        edit PVSystem.myPV ControlMode=GFL
        
        close line.0_1 terminal=1
        set number=4690
        solve
        """)
    # Define the outage window in the OpenDSS model
    # as seen in the OpenDSS example code online for islanded Microgrids:   
        
        #=
        # Step 1: run the OpenDSS model first for the non-outage times
        dss("set mode=yearly number=4050") # simulate the first 4050 hours
        dss("Solve")

        # Step 2: run outage:
        dss("Open Line.0_1  terminal=1") # open the line (creates an outage in the distribution system)
        dss("edit storage.ElectricStorageNode6 State=Discharging ControlMode=GFM")
        dss("edit PVSystem.PVNode10") # ControlMode=GFM")
        dss("set number=20") # a 20 hour outage
        dss("Solve")

        # Step 3: run the rest of the simulation without the outage:
        dss("edit storage.ElectricStorageNode6 State=Charging ControlMode=GFL")
        dss("edit PVSystem.PVNode10") # ControlMode=GFL")
        dss("Close Line.0_1 terminal=1")
        dss("set number=4690")
        dss("Solve")
        =#


    #dss("Solve")

    # can export the monitor data to a csv file
    dss("Set ShowExport = No")
    dss("CD C:/Users/toddleif/Documents/OpenDSSResults/testing_17Jan")
    dss("Export monitor monitor_1")  # This exports all of the data from the monitor into a csv document

    # See this export for the problem
        # OpenDSS's V1 value is not close to 10 kV at all, but it thinks the per unit value is close to 1
    dss("Export Voltages")  # exports the voltages (I think from the last time step, this also shows the per unit value too)

    # Access the data from the monitors directly
    #OpenDSSDirect.Monitors.Element("line_test") # This appears to cause problems with accessing the data, use the .Name instead # sets this as the element of interest I think
    #OpenDSSDirect.Monitors.NumChannels()  #displays the number of channels on the monitor
    #OpenDSSDirect.Monitors.Header()  # displays a list of the headers from that monitor's data
    #OpenDSSDirect.Monitors.Element()  # displays what monitor is currently being looked at
    
    Monitors = OpenDSSDirect.Monitors.AllNames() # shows the names of all of the monitors
    NodeResults = Dict() # initiate a dictionary to store the results
    # Save data from all of the monitors
    for i in 1:length(Monitors)
        OpenDSSDirect.Monitors.Name(Monitors[i]) # set the active monitor, which is the monitor to pull data from
        MonitorName = OpenDSSDirect.Monitors.Name() # displays the name of the monitor
        DataList = OpenDSSDirect.Monitors.Header() # determine the headers available in the monitor data
        
        # TODO: change the 22.7 to the base voltage at the monitory (note: the base voltage may change based on the use of transformers) 
        HeaderIndex = 1
        Data_raw = OpenDSSDirect.Monitors.Channel(HeaderIndex)
        # use the sqrt(3) if it's three phase power (I think)
        #Data_voltage = (Data_raw*(sqrt(3)/1000))/22.7  # normalize this to the base voltage to get a perunit value
        
        Data_voltage = (Data_raw*(1/1000))/22.7
        DataPulled = DataList[1] # shows the header of the data that was pulled

        NodeResults[MonitorName] = Dict([DataPulled => Data_voltage])  # save results to a dictionary; create a subdictionary for each node so can save other results for that node

        # TODO: plot the results based on user defined plotting time window
        DayNumber = collect(1:8760)/24
        Plots.plot(Data_voltage, label = "OpenDSS Solution")
        Plots.xlabel!("Day Number In Year")
        Plots.ylabel!("Voltage (kV)") 
        Plots.xlims!(4000,4250)
        display(Plots.title!("Voltage at $(MonitorName)"))
    end

    SolutionConverged = OpenDSSDirect.Solution.Converged()  # see if the solution converged in OpenDSS
    SolutionConvergenceTolerance = OpenDSSDirect.Solution.Convergence()  # see the convergence tolerance, can also use a similar method to define the convergence tolerance when creating the OpenDSS model
    
    NumberOfPVSystems = OpenDSSDirect.PVsystems.Count() 
    PVPowerOutput_LastTimeStep = OpenDSSDirect.PVsystems.kW()

    # Plot the total load and total generation

    TotalLoad = REoptresults[2]["ElectricLoad"]["load_series_kw"] + 
                REoptresults[5]["ElectricLoad"]["load_series_kw"] +
                REoptresults[7]["ElectricLoad"]["load_series_kw"] +
                REoptresults[9]["ElectricLoad"]["load_series_kw"]


    # to get the per unit voltage at all nodes 
        # note: this is just for one time step (I believe just the last time step), need to add a monitor to get results for all time steps
        # note: this method is from Nick Laws's Branch Flow Model
    voltages_perunit = Dict()
    for b in OpenDSSDirect.Circuit.AllBusNames()
        OpenDSSDirect.Circuit.SetActiveBus(b)
        voltages_perunit[b] = OpenDSSDirect.Bus.puVmagAngle()[1:2:end]
    end
    # End of Nick Laws's Method

    # TODO: add additional outputs from OpenDSS

    return SolutionConverged
end

function Results_Processing(results, Outage_Results, OpenDSSResults, Microgrid_Settings, ldf_inputs_dictionary, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel)

    InputsList = Microgrid_Settings["REoptInputsList"]
    LineFromSubstationToFacilityMeter = ldf_inputs_dictionary["SubstationLocation"] * "-" * Microgrid_Settings["FacilityMeter_Node"]
    #NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"]))

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
                                                                    (results[node_temp]["PV"]["year_one_energy_produced_kwh"] - sum(results[node_temp]["PV"]["electric_curtailed_series_kw"]/Microgrid_Settings["TimeStepsPerHour"]))
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
    if Microgrid_Settings["Generate_CSV_of_outputs"] == true
        @info "Generating CSV of outputs"
        DataLabels = []
        Data = []
        
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

        push!(DataLabels,"  Maximum power flow from substation")
        push!(Data, (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0)))
        push!(DataLabels,"  Minimum power flow from substation")
        push!(Data, (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0)))
        push!(DataLabels,"  Average power flow from substation")
        push!(Data, (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0)))

        # Add the microgrid outage results to the dataframe
        push!(DataLabels, "----Microgrid Outage Results----")
        push!(Data, "")
        if Microgrid_Settings["RunOutageSimulator"] == true
            for i in 1:length(Microgrid_Settings["LengthOfOutages_timesteps"])
                OutageLength = Microgrid_Settings["LengthOfOutages_timesteps"][i]
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
               
        # Add OpenDSS results to the results dataframe
        if Microgrid_Settings["RunOpenDSS"] == true
            OpenDSSSolutionConverged = OpenDSSResults

            push!(DataLabels,"---OpenDSS Solution---")
            push!(Data,"")

            push!(DataLabels,"Did the solution converge?")
            push!(Data,OpenDSSSolutionConverged)
        end

        # Save the dataframe as a csv document
        dataframe_results = DataFrame(Labels = DataLabels, Data = Data)
        CSV.write(Microgrid_Settings["FolderLocation"]*"/results_"*TimeStamp*"/Results_Summary_"*TimeStamp*".csv", dataframe_results)
        
        # Save the Line Flow summary for each line to a different csv
        CSV.write(Microgrid_Settings["FolderLocation"]*"/results_"*TimeStamp*"/Results_Line_Flow_Summary_"*TimeStamp*".csv", DataFrame_LineFlow_Summary)
    end 

    #Display results if the "Display_Results" input is set to true
    if Microgrid_Settings["Display_Results"] == true
        print("\n-----")
        print("\nResults:") 
        print("\n   The computation time was: "*string(ComputationTime_EntireModel))
    
        print("Line Flow Results")
        display(DataFrame_LineFlow_Summary)
    
        print("\nSubstation data: ")
        print("\n   Maximum power flow from substation: "*string(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"])))
        print("\n   Minimum power flow from substation: "*string(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"])))
        print("\n   Average power flow from substation: "*string(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"])))
    
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

# Function to check for errors in the data inputs for the model
function RunDataChecks(Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary)

    ps = REopt_dictionary
    
    for p in ps
        node_temp = p.s.site.node
        if p.s.settings.facilitymeter_node != Microgrid_Settings["FacilityMeter_Node"]
            throw(@error("The facilitymeter_node input for each REopt node must equal the FacilityMeter_Node defined in the microgrid settings, which is $(FacilityMeter_Node)"))
        end
        if p.s.settings.time_steps_per_hour != Microgrid_Settings["TimeStepsPerHour"]
            throw(@error("The time steps per hour for each REopt node must match the time steps per hour defined in the microgrid settings dictionary"))
        end
        if p.s.settings.time_steps_per_hour != Int(ldf_inputs_dictionary["T"]/8760)
            throw(@error("The number of time steps in the ldf_inputs_dictionary must correlate to the time_steps_per_hour in all REopt nodes"))
        end
        if string(p.s.site.node) ∉ keys(ldf_inputs_dictionary["load_nodes"]) #  ∉ is the "not in" symbol
            throw(@error("The REopt node $(node_temp) is not in the list of nodes in the ldf_inputs_dictionary"))
        end
        if Microgrid_Settings["Critical_Load_Method"] == "Fraction"
            if string(p.s.site.node) ∉ keys(Microgrid_Settings["Critical_Load_Fraction"])
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load fraction in the Critical_Load_Fraction input dictionary"))
                end
            end
        end
        if Microgrid_Settings["Critical_Load_Method"] == "TimeSeries"
            if string(p.s.site.node) ∉ keys(Microgrid_Settings["Critical_Load_TimeSeries"])
                if sum(p.s.electric_load.loads_kw) > 0
                    throw(@error("The REopt node $(node_temp) does not have an assigned critical load timeseries profile in the Critical_Load_TimeSeries input dictionary"))
                end
            end
        end
        # TODO: add data check to ensure that if a critical load method is defined, then there must be either a critical load fraction or a critical load timeseries dictionary   
        
        if Int(length(p.s.electric_load.loads_kw)) != Int(8760 * Microgrid_Settings["TimeStepsPerHour"])
            throw(@error("At REopt node $(node_temp), the length of the electric loads vector does not correlate with the time steps per hour defined in the Microgrid_Settings dictionary"))
        end
    end

    if ldf_inputs_dictionary["v0_input"] > ldf_inputs_dictionary["v_uplim_input"]
        throw(@error("In the ldf_inputs_dictionary, the v0_input value must be less than the v_uplim_input value"))
    end 

    if ldf_inputs_dictionary["v0_input"] < ldf_inputs_dictionary["v_lolim_input"]
        throw(@error("In the ldf_inputs_dictionary, the v0_input value must be greater than the v_lolim_input value"))
    end   
    
    if Microgrid_Settings["MicrogridType"] != "CommunityDistrict" && Microgrid_Settings["MicrogridType"] != "BehindTheMeter" && Microgrid_Settings["MicrogridType"] != "OffGrid"
        throw(@error("An invalid microgrid type was provided in the inputs"))
    end

    if Microgrid_Settings["MicrogridType"] != "CommunityDistrict"
        @warn("For the community district microgrid type, the electricity tariff for the facility meter node should be 0")
    end

    if Microgrid_Settings["Generate_Results_Plots"] == true
        for i in Microgrid_Settings["RunNumbersForPlottingOutageSimulatorResults"]
            if i > Microgrid_Settings["NumberOfOutagesToEvaluate"]
                throw(@error("In the Microgrid_Settings dictionary, all values for the RunNumbersForPlottingOutageSimulatorResults must be less than the NumberOfOutagesToEvaluate"))
            end
        end
    end

    if Microgrid_Settings["Critical_Load_Method"] == "Fraction"
        for x in values(Microgrid_Settings["Critical_Load_Fraction"])
            if x >= 5.0
                throw(@error("The Critical_Load_Fraction load fraction should be entered as a fraction, not a percent. The model currently limits the Critical_Load_Fraction to 5.0 (or 500%) to reduce possibility of user error. "))
            end
        end
    end

    if Microgrid_Settings["SingleOutageStartTimeStep"] > Microgrid_Settings["SingleOutageStopTimeStep"]
        throw(@error("In the Microgrid_Settings dictionary, the single outage start time must be a smaller value than the single outage stop time"))
    end
    if Microgrid_Settings["SingleOutageStopTimeStep"] > (8760 * Microgrid_Settings["TimeStepsPerHour"])
        TotalNumberOfTimeSteps = Int(8760 * Microgrid_Settings["TimeStepsPerHour"])
        throw(@error("In the Microgrid_Settings dictionary, the defined outage stop time must be less than the total number of time steps, which is $(TotalNumberOfTimeSteps)"))
    end
end