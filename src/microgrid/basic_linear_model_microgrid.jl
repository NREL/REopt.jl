# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

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
DataFrame_LineFlow = DataFrame(fill(Any[],7), [:Line, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Rated_Power_kW])
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

    DataFrame_LineFlow_temp = DataFrame([("Line "*string(edge)) DataLineFlow[1] DataLineFlow[2] DataLineFlow[3] DataLineFlow[4] DataLineFlow[5] DataLineFlow[6]], [:Line, :Minimum_LineFlow_kW, :Maximum_LineFlow_kW, :Average_LineFlow_kW, :Line_Nominal_Amps_A, :Line_Nominal_Voltage_V, :Line_Max_Rated_Power_kW])
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
        
        for node in ldf_inputs.busses
            print("The loop number is: $(node)")
            if node == ldf_inputs.substation_bus
                # Do nothing, because the substation node is plotted above
            else
                # Find the upstream node for plotting
                upstream_node = i_to_j(node, ldf_inputs)[1]
                Color = Voltage_Color_Pairing[BusNominalVoltages_Summary[node]]
                Plots.plot!([distances[upstream_node], distances[node]], [Dictionary_Node_Data_Series[upstream_node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep], Dictionary_Node_Data_Series[node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], linecolor = Color, linewidth=3, label=false)

                if BusNominalVoltages_Summary[node] in Unique_Voltages  # Plot the marker with a label             
                    Plots.plot!([distances[node]], [Dictionary_Node_Data_Series[node]["VoltageMagnitude_PerUnit"][Microgrid_Inputs.PlotVoltageDrop_VoltageTimeStep]], marker = (:circle,6), markercolor = Color, linewidth=3, linecolor=Color, label=BusNominalVoltages_Summary[node]*" V")
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
    days = TimeSteps/(8760* (length(TimeSteps)/8760))
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
    line_upgrade_results = DataFrame(fill(Any[], 6), [:Line, :Upgraded, :MaximumRatedAmps, :rmatrix, :xmatrix, :UpgradeCost])
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

        line_upgrade_results_temp = DataFrame([line upgraded maximum_amps rmatrix xmatrix upgraded_cost ], [:Line, :Upgraded, :MaximumRatedAmps, :rmatrix, :xmatrix, :UpgradeCost])
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


