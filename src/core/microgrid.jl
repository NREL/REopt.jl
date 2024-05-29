#=
# Code for running the REopt microgrid analysis capability
=#

# The main function to run all parts of the model
function Microgrid_Model(Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary)
    # This function accepts three inputs:
        # 1. The Microgrid_Inputs
        # 2. ldf_inputs_dictionary (for LinDistFlow)
        # 3. The REopt inputs dictionaries 

    cd(Microgrid_Settings["FolderLocation"])
    DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results = Microgrid_REopt_Model(Microgrid_Settings, ldf_inputs_dictionary, REopt_dictionary) 

    if Microgrid_Settings["RunOutageSimulator"] == "Yes"
        OutageLengths = Microgrid_Settings["LengthOfOutages_timesteps"] 
        TimeStepsPerHour = Microgrid_Settings["TimeStepsPerHour"] 
        NumberOfOutagesToTest = Microgrid_Settings["NumberOfOutagesToEvaluate"]
        Outage_Results = Dict([])
        for i in 1:length(OutageLengths)
            OutageLength = OutageLengths[i]
            OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived = Microgrid_OutageSimulator(DataDictionaryForEachNode; NumberOfOutagesToTest = NumberOfOutagesToTest, ldf_inputs_dictionary = ldf_inputs_dictionary, TimeStepsPerHour_input = TimeStepsPerHour, OutageLength_TimeSteps_Input = OutageLength)
            Outage_Results["$(OutageLength_TimeSteps)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, "NumberOfRuns" => RunNumber, "NumberOfOutagesSurvived" => SuccessfullySolved ])
        end 
    else
        print("\n  Not running the microgrid outage simulator in this model")
        Outage_Results = Dict(["NoOutagesTested" => Dict(["Not evaluated" => "Not evaluated"])])
    end 

    # TODO: configure OpenDSS to run as an islanded microgrid during the defined outage
    
    if Microgrid_Settings["RunOpenDSS"] == true
        using OpenDSSDirect
        OpenDSSResults = RunOpenDSS(results, Microgrid_Settings)
    else
        OpenDSSResults = "OpenDSS Not Run" 
    end

    # Generate a csv file with outputs from the model
    DataLabels = []
    Data = []
    NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"]))
    push!(DataLabels, "----REopt Results----")
    push!(Data, "")
    for n in NodeList
        NodeNumberTempB = parse(Int,n)
        InputsDictionary = Dict[] # reset the inputs dictionary to an empty dictionary before redefining
    
        for n in InputsList
            if n["Site"]["node"] == NodeNumberTempB
                InputsDictionary = n
                push!(DataLabels, "**Node $(NodeNumberTempB)")
                push!(Data, "")
            end 
        end
        if "PV" in keys(results[NodeNumberTempB])
            push!(DataLabels, "PV Size (kw)")
            push!(Data, results[NodeNumberTempB]["PV"]["size_kw"])
            push!(DataLabels, "Min and Max PV sizing input, kW")
            push!(Data, string(InputsDictionary["PV"]["min_kw"])*" and "*string(InputsDictionary["PV"]["max_kw"]))
            #print("\n      Minimum Real Power Flow from line 9-10: "*string(minimum(NetRealLineFlow[NodeNumber,:]))* "  <- if negative, then power is flowing out of node 10") # if this is negative then exporting from node 10
            #print("\n      Maximum Real Power Flow from line 9-10: "*string(maximum(NetRealLineFlow[NodeNumber,:]))) 
            #print("\n      Max PV Power Curtailed: "*string(round(maximum(results[NodeNumberTempB]["PV"]["electric_curtailed_series_kw"]), digits =2)))
            #print("\n      Max PV Power Exported to Grid from node: "*string(round(maximum(results[NodeNumberTempB]["PV"]["electric_to_grid_series_kw"]), digits =2))) 
        else
            push!(DataLabels, "PV")
            push!(Data, " None")
        end 
    
        if "Generator" in keys(results[NodeNumberTempB])
            push!(DataLabels, "Generator (kw)")
            push!(Data, round(results[NodeNumberTempB]["Generator"]["size_kw"], digits =2))
            
            #print("\n  Generator size (kW): "*string(round(results[NodeNumberTempB]["Generator"]["size_kw"], digits =2)))
            #print("\n     Maximum generator power to load (kW): "*string(round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2)))
            #print("\n       Average generator power to load (kW): "*string(round(mean(results[NodeNumberTempB]["Generator"]["electric_to_load_series_kw"].data), digits =2)))
            #print("\n     Maximum generator power to grid (kW): "*string(round(maximum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
            #print("\n       Minimum generator power to grid (kW): "*string(round(minimum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
            #print("\n       Minimum generator power to grid (kW): "*string(minimum(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data)))
            #print("\n       Average generator power to grid (kW): "*string(round(mean(results[NodeNumberTempB]["Generator"]["electric_to_grid_series_kw"].data), digits =2)))
        else 
            push!(DataLabels, "Generator")
            push!(Data, " None")   
        end 
        if "ElectricStorage" in keys(results[NodeNumberTempB])
            if results[NodeNumberTempB]["ElectricStorage"]["size_kw"] > 0 
                push!(DataLabels, "Battery Power (kW)")
                push!(Data, format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kw"], digits =2), commas = true)) 
                push!(DataLabels, "Battery Capacity (kWh)")
                push!(Data, format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kwh"], digits =2), commas = true)) 
                
                #print("\n  Battery power (kW): "*format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kw"], digits =2), commas = true))
                #print("\n    Battery capacity (kWh): "*format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kwh"], digits =2), commas = true))
                #print("\n    Average Battery SOC (fraction): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
                #print("\n      Minimum Battery SOC (fraction): "*format(round(minimum(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
                #print("\n    Average battery to load (kW): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
                #print("\n      Maximum battery to load (kW): "*format(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
                #print("\n    Average battery to grid (kW): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
                #print("\n      Maximum battery to grid (kW): "*format(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
            else
                push!(DataLabels, "Battery")
                push!(Data, " None")   
            end
        else
            push!(DataLabels, "Battery")
            push!(Data, " None")   
        end 
    end
    
    # Add the microgrid outage results to the dataframe
    push!(DataLabels, "----Microgrid Outage Results----")
    push!(Data, "")
    if Microgrid_Settings["RunOutageSimulator"] == "Yes"
        for i in 1:length(OutageLengths)
            #push!(DataLabels)
            OutageLength = OutageLengths[i]
            push!(DataLabels, "--Outage Length: $(OutageLength) time steps--")
            push!(Data, "")
            push!(DataLabels, "Percent of Outages Survived")
            push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["PercentSurvived"])
            push!(DataLabels, "Total Number of Outages Tested")
            push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfRuns"])
            push!(DataLabels, "Total Number of Outages Survived")
            push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfOutagesSurvived"])
        end 
    else 
        push!(DataLabels,"Outage modeling was not run")
        push!(Data,"")
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
    CSV.write(Microgrid_Settings["FolderLocation"]*"/Results/ResultsExport.csv", dataframe_results)

    # Compile output data into a dictionary
    CompiledResults = Dict([
                            ("DataDictionaryForEachNode", DataDictionaryForEachNode), 
                            ("FromREopt_Dictionary_LineFlow_Power_Series", Dictionary_LineFlow_Power_Series), 
                            ("FromREopt_Dictionary_Node_Data_Series", Dictionary_Node_Data_Series), 
                            ("ldf_inputs", ldf_inputs),
                            ("REopt_results", results),
                            ("Outage_Results", Outage_Results),
                            ("OpenDSSResults", OpenDSSResults)
                            ])
    return CompiledResults  
end

# Function to run the REopt analysis 
function Microgrid_REopt_Model(Microgrid_Inputs, ldf_inputs_dictionary, REoptInputs)
    cd(Microgrid_Inputs["FolderLocation"])
    ldf_inputs_dictionary = ldf_inputs_dictionary
    ps = REoptInputs

    MicrogridType = Microgrid_Inputs["MicrogridType"]
    AllowExportBeyondSubstation = Microgrid_Inputs["AllowExportBeyondSubstation"]
    SubstationExportLimit = Microgrid_Inputs["SubstationExportLimit"]
    ElectricityCostFromSubstation_perkwh = Microgrid_Inputs["ElectricityCostFromSubstation_perkwh"]
    GeneratorFuelGallonAvailable = Microgrid_Inputs["GeneratorFuelGallonAvailable"]
    AnalysisYears = Microgrid_Inputs["AnalysisYears"]
    ElecCostEscalationRate = Microgrid_Inputs["ElecCostEscalationRate"]
    HostDiscountRateFraction = Microgrid_Inputs["HostDiscountRateFraction"]
    OutageStartTimeStep = Microgrid_Inputs["SingleOutageStartTimeStep"]
    OutageStopTimeStep = Microgrid_Inputs["SingleOutageStopTimeStep"]

    pwf_e_multinode = REopt.annuity(AnalysisYears, ElecCostEscalationRate, HostDiscountRateFraction)

    NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"])) 
    
    # Add the LDF inputs
    # this can be done using two methods:
        # 1. importing an OpenDSS file for the lines and linecodes (the method used in this script)
        # 2. manually building out a distribution network information

    ldf_inputs = LinDistFlow.Inputs(
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
        Ntimesteps = ldf_inputs_dictionary["T"],
        regulators = ldf_inputs_dictionary["VoltageRegulatorDictionary"]

    )

    # Determine the voltages at each line, using 
    LineNominalVoltages_Summary, BusNominalVoltages_Summary = LinDistFlow.DetermineLineNominalVoltage(ldf_inputs)
    #BusNominalVoltages_withdashes = Dict([])
    #for i in keys(BusNominalVoltages_Summary) 
    #    dashed_key = replace(keys, "_" => "-")
    #    BusNominalVoltages_withdashes_temp = Dict([dashed_key => BusNominalVoltages_Summary[i]])
    #    merge!(BusNominalVoltages_withdashes,BusNominalVoltages_withdashes_temp)
    #end 
    
    #return ldf_inputs 
    # For a Community District microgrid:
        # Redefine the electricity tariff, if needed, for when the grid outage occurs - this will allow for power sharing between the nodes during an outage
    if MicrogridType == "CommunityDistrict"
        for x in REoptInputs
            x.s.electric_tariff.energy_rates[OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
            x.s.electric_tariff.export_rates[:WHL][OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        end 
    end
        #=
        REoptInputA.s.electric_tariff.energy_rates[OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        REoptInputA.s.electric_tariff.export_rates[:WHL][OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
    
        REoptInputB.s.electric_tariff.energy_rates[OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        REoptInputB.s.electric_tariff.export_rates[:WHL][OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
    
        REoptInputC.s.electric_tariff.energy_rates[OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        REoptInputC.s.electric_tariff.export_rates[:WHL][OutageStartTimeStep:OutageStopTimeStep] .= 0.00001
        =#
    #end 

    print("\n Recording the start time")
    print("\n") 
    StartTime = now()
    
    m = Model(Xpress.Optimizer)
    print("Building the REopt model")
    build_reopt!(m,ps)
    print("testing 2")
    LinDistFlow.build_ldf!(m, ldf_inputs, ps) # The ps is an input here because this input structure for "build_ldf!" is defined in REopt's extend.jl file
    #multinode_build_ldf!(m, ldf_inputs, ps)
    print("testing 3")

# FOR A BEHIND THE METER MICROGRID:
# Prevent power from being exported to the grid beyond the node 1 meter:
if AllowExportBeyondSubstation == "NoExport"
    JuMP.@constraint(m, [t in 1:8760], m[:Pᵢⱼ]["0-15",t] >= 0 ) 
else
    JuMP.@constraint(m, [t in 1:8760], m[:Pᵢⱼ]["0-15",t] >=  ((SubstationExportLimit*1000)/ ldf_inputs.Sbase) )  
end 

#For an off-grid microgrid
if MicrogridType == "Offgrid"
    # prevent power from flowing in from the substation
    @info "Adding constraints for an offgrid microgrid"
    JuMP.@constraint(m, [t in 1:8760], m[:Pᵢⱼ]["0-15",t] == 0 ) 
end 

# if an outage is modelled, prevent power from flowing into the substation at those times
if (OutageStopTimeStep - OutageStartTimeStep) > 0
    print("\n  Adding an outage to the model")
    JuMP.@constraint(m, [t in OutageStartTimeStep:OutageStopTimeStep], m[:Pᵢⱼ]["0-15",t] == 0) 
else 
    print("\n  No outage in the model")
end

# FOR A COMMUNITY ISLANDED DURING A GRID OUTAGE:
if MicrogridType == "CommunityDistrict"
    @info "Applying additional constraints for a Community District microgrid"
    if ElectricityCostFromSubstation_perkwh != 0  # set this to zero because electricity is being charged at each node, not at the substation
        @warn "Setting the cost per kWh of electricity from the substation to 0 because a Community District microgrid is being modelled and electricity is charged at each node"
        ElectricityCostFromSubstation_perkwh = 0
    end 
    
    if (OutageStopTimeStep - OutageStartTimeStep) > 0
        #Prevent the generator from operating during non-grid outage times
        for Node in NodeList
            JuMP.@constraint(m, [t in 1:(OutageStartTimeStep-1)], m[Symbol("dvRatedProduction_"*Node)]["Generator",t] == 0 )
            JuMP.@constraint(m, [t in (OutageStopTimeStep+1):8760], m[Symbol("dvRatedProduction_"*Node)]["Generator",t] == 0 )    
        end
    end 
end

# TODO: implement utility tariff demand rates into the model
#DemandRates = [6,6,8,8,8,8,8,8,8,8,8,8]
#dv = "TotalDemand_Charge_YearOne"
#m[Symbol(dv)] = @variable(m, base_name=dv, lower_bound=0)

#@constraint(m, m[Symbol("TotalDemand_Charge_YearOne")] >=

                # This does not work (there appears to be an issue with the maximum function):
                #(DemandRates[1]*sum(((m[:Pᵢⱼ]["0-1",1:31*24])*1e6)/1000)) ) #.+ # Jan 31 is day #31 
                #(DemandRates[2]*maximum(((m[:Pᵢⱼ]["0-1",31*24:59*24])*1e6)/1000)) .+ # Feb 28 is day #59
                #(DemandRates[3]*maximum(((m[:Pᵢⱼ]["0-1",59*24:90*24])*1e6)/1000)) .+ # Mar 31 is day #90
                #(DemandRates[4]*maximum(((m[:Pᵢⱼ]["0-1",90*24:120*24])*1e6)/1000)) .+ # Apr 30 is day #120
                #(DemandRates[5]*maximum(((m[:Pᵢⱼ]["0-1",120*24:151*24])*1e6)/1000)) .+ # May 31 is day #151
                #(DemandRates[6]*maximum(((m[:Pᵢⱼ]["0-1",151*24:181*24])*1e6)/1000)) .+ # Jun 30 is day #181
                #(DemandRates[7]*maximum(((m[:Pᵢⱼ]["0-1",181*24:212*24])*1e6)/1000)) .+ # Jul 31 is day #212
                #(DemandRates[8]*maximum(((m[:Pᵢⱼ]["0-1",212*24:243*24])*1e6)/1000)) .+ # Aug 31 is day #243
                #(DemandRates[9]*maximum(((m[:Pᵢⱼ]["0-1",243*24:273*24])*1e6)/1000)) .+ # Sep 30 is day #273
                #(DemandRates[10]*maximum(((m[:Pᵢⱼ]["0-1",273*24:304*24])*1e6)/1000)) .+ # Oct 31 is day #304
                #(DemandRates[11]*maximum(((m[:Pᵢⱼ]["0-1",304*24:334*24])*1e6)/1000)) .+ # Nov 30 is day #334
                #(DemandRates[12]*maximum(((m[:Pᵢⱼ]["0-1",334*24:365*24])*1e6)/1000))  # Dec 31 is day #365
          #  ) 

#@constraint(m_outagesimulator, [ts in [1:TimeSteps]], (m_outagesimulator[Symbol("TotalExport_"*n)] .== m_outagesimulator[Symbol("dvPVToGrid_"*n)][ts] + 
#m_outagesimulator[Symbol("dvBatToGridWithEfficiency_"*n)][ts] + 
#m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts]))

# Note: the objective accounts for costs of all REopt nodes input into the model
@objective(m, Min, sum(m[Symbol(string("Costs_", p.s.site.node))] for p in ps) + 
                   (((sum(m[:Pᵢⱼ]["0-15",1:8760])*5000)/1000) * pwf_e_multinode * ElectricityCostFromSubstation_perkwh) #+  # the lifecycle energy cost
            )

print("The optimization is starting")
set_optimizer_attribute(m, "MIPRELSTOP", 0.001) 
optimize!(m)
print("The optimization is complete. Reading the results.") 

results = reopt_results(m, ps) 

print("\n Recording the end time")
print("\n")
EndTime = now()
ComputationTime = EndTime - StartTime


# SECTION 2:  Processing results from the solution *************************************************************
Node_Connections = [[parse(Int,i),parse(Int,j)] for j in ldf_inputs.busses for i in i_to_j(j, ldf_inputs)]

# The variables Pᵢⱼ and Qᵢⱼ are indexed by the line value (shown in the edges variable below) in the LinDistFlow model 
edges = [string(i*"-"*j) for j in ldf_inputs.busses for i in i_to_j(j, ldf_inputs)]

# The variables Pⱼ and Qⱼ are indexed by the bus value (in the ldf_inputs) in the LinDistFlow model
    # look at the value.(m[:Pᵢⱼ]) in the terminal to see the values and indexes
busses = ldf_inputs.busses

# compute values for each line
DataLineFlow = zeros(3)
DataFrame_LineFlow = DataFrame(["empty" 0 0 0], [:LineCode, :Minimum_LineFlow, :Maximum_LineFlow, :Average_LineFlow])
Dictionary_LineFlow_Power_Series = Dict([])

for edge in edges
    # store line power flows in a dictionary 
    NetRealLineFlow = (value.(m[:Pᵢⱼ][edge,:]).data* ldf_inputs.Sbase)/1000 # 
    NetReactiveLineFlow = (value.(m[:Qᵢⱼ][edge,:]).data*ldf_inputs.Sbase)/1000 

    Dictionary_LineFlow_Power_Series_temp = Dict([
                                                    (edge, Dict([
                                                        ("NetRealLineFlow", NetRealLineFlow),
                                                        ("NetReactiveLineFlow", NetReactiveLineFlow)
                                                    ]))
                                                    ])
    merge!(Dictionary_LineFlow_Power_Series, Dictionary_LineFlow_Power_Series_temp)

    # create summary dataframe
    DataLineFlow[1] = minimum(NetRealLineFlow[:])
    DataLineFlow[2] = maximum(NetRealLineFlow[:])
    DataLineFlow[3] = mean(NetRealLineFlow[:])

    DataFrame_LineFlow_temp = DataFrame([edge DataLineFlow[1] DataLineFlow[2] DataLineFlow[3]], [:LineCode, :Minimum_LineFlow, :Maximum_LineFlow, :Average_LineFlow])
    DataFrame_LineFlow = append!(DataFrame_LineFlow,DataFrame_LineFlow_temp)
end
# compute values for each node:
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

#Compute

# Switch to this for-loop when all of this code is transferred into a function (currently there is a variable scope problem)

TotalLoad_series = zeros(8760) # initiate the total load as 0
for n in NodeList
    NodeNum = parse(Int,n)
    TotalLoad_series = TotalLoad_series + results[NodeNum]["ElectricLoad"]["load_series_kw"] 
end

#=
TotalLoad_series = results[2]["ElectricLoad"]["load_series_kw"] + 
                results[3]["ElectricLoad"]["load_series_kw"] + 
                results[4]["ElectricLoad"]["load_series_kw"] + 
                results[5]["ElectricLoad"]["load_series_kw"] + 
                results[6]["ElectricLoad"]["load_series_kw"] + 
                results[7]["ElectricLoad"]["load_series_kw"] + 
                results[8]["ElectricLoad"]["load_series_kw"] + 
                results[9]["ElectricLoad"]["load_series_kw"] + 
                results[10]["ElectricLoad"]["load_series_kw"] + 
                results[14]["ElectricLoad"]["load_series_kw"] +
                results[20]["ElectricLoad"]["load_series_kw"]
=# 
Vbase_input = ldf_inputs_dictionary["Vbase_input"]
v_uplim_input = ldf_inputs_dictionary["v_uplim_input"]
v_lolim_input = ldf_inputs_dictionary["v_lolim_input"] 

# Plot showing that the voltage is within defined +/- percentage of the nominal voltage
for n in NodeList
    Plots.plot(Dictionary_Node_Data_Series[n]["VoltageMagnitude_kV"], label = "Voltage Magnitude (kV)", linewidth = 2, line = (:dash), size = (1000,400))
    Plots.plot!((parse(Float64,BusNominalVoltages_Summary[n])*v_uplim_input*(ones(8760))/1000), label = "Upper limit (kV)")
    Plots.plot!((parse(Float64,BusNominalVoltages_Summary[n])*v_lolim_input*(ones(8760))/1000), label = "Lower limit (kV)")
    Plots.xlabel!("Hour of the Year") 
    Plots.ylabel!("Voltage (kV)")
    #Plots.xlims!(4000,4100)
    display(Plots.title!("Node "*n*": Voltage"))
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

# Plot the network-wide power use 

# determine all of the nodes with PV and determine total PV output across the entire network
NodesWithPV = []
for i in keys(results)
    if "PV" in keys(results[i])
        push!(NodesWithPV, i)
    end
end
PVOutput = zeros(8760)
for NodeNumberTemp in NodesWithPV
    PVOutput = PVOutput + results[NodeNumberTemp]["PV"]["electric_to_load_series_kw"] + results[NodeNumberTemp]["PV"]["electric_to_grid_series_kw"]
end

# determine all of the nodes with Battery
NodesWithBattery = []
for i in keys(results)
    if "ElectricStorage" in keys(results[i])
        push!(NodesWithBattery, i)
    end
end
BatteryOutput = zeros(8760)
for NodeNumberTemp in NodesWithBattery
    if results[NodeNumberTemp]["ElectricStorage"]["size_kw"] > 0  # include this if statement to prevent trying to add in empty electric storage time series vectors
        BatteryOutput = BatteryOutput + results[NodeNumberTemp]["ElectricStorage"]["storage_to_load_series_kw"] + results[NodeNumberTemp]["ElectricStorage"]["storage_to_grid_series_kw"] 
    end
end

# determine all of the nodes with generator
NodesWithGenerator = []
for i in keys(results)
    if "Generator" in keys(results[i])
        push!(NodesWithBattery, i)
    end
end
GeneratorOutput = zeros(8760)
for NodeNumberTemp in NodesWithGenerator
    GeneratorOutput = GeneratorOutput + results[NodeNumberTemp]["Generator"]["electric_to_load_series_kw"] + results[NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"] + results[NodeNumberTemp]["Generator"]["electric_to_storage_series_kw"] 
end

days = collect(1:8760)/24
Plots.plot(days, TotalLoad_series, label="Total Load")
Plots.plot!(days, PVOutput, label="Combined PV Output")
Plots.plot!(days, BatteryOutput, label = "Combined Battery Output")
Plots.plot!(days, GeneratorOutput, label = "Combined Generator Output")
Plots.plot!(days, Dictionary_LineFlow_Power_Series["0-15"]["NetRealLineFlow"])
#Plots.plot!([4050, 4050],[0,150], label= "Outage Start")
#Plots.plot!([4070, 4070],[0,150], label= "Outage End")
Plots.xlims!(4000/24,4100/24)
display(Plots.title!("System Wide Power Demand and Generation"))


# Plot the real power load and real power injection data for each REopt node:
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
end


# Plot all of the real and reactive power flow through each distribution line
for edge in edges
    Plots.plot(Dictionary_LineFlow_Power_Series[edge]["NetRealLineFlow"], label = "Real Power Flow" )
    Plots.plot!(Dictionary_LineFlow_Power_Series[edge]["NetReactiveLineFlow"], label = "Reactive Power Flow" )
    Plots.xlabel!("Hour of the Year")
    Plots.ylabel!("Power (kW)")
    Plots.title!("Distribution Line $(edge): Power Flow")
    display(Plots.xlims!(Microgrid_Inputs["ResultPlotsStartTimeStep"],Microgrid_Inputs["ResultPlotsEndTimeStep"]))
end
    

print("\n-----")
print("\nResults:") 
print("\n   The computation time was: "*string(ComputationTime))
#print("\nPower Loss data:")
#print("\n  The Maximum percent power loss of total load is: "*string(round((100*maximum(Fraction_PowerLoss_real_To_TotalLoad)), digits = 10))*" %")
#print("\n  The average percent power loss of total load is: "*string(round((100*mean(Fraction_PowerLoss_real_To_TotalLoad)), digits = 10))*" %")

print("Line Flow Results")
display(DataFrame_LineFlow)

print("\nSubstation data: ")
print("\n   Maximum power flow from substation: "*string(maximum(Dictionary_LineFlow_Power_Series["0-15"]["NetRealLineFlow"])))
print("\n   Minimum power flow from substation: "*string(minimum(Dictionary_LineFlow_Power_Series["0-15"]["NetRealLineFlow"])))
print("\n   Average power flow from substation: "*string(mean(Dictionary_LineFlow_Power_Series["0-15"]["NetRealLineFlow"])))

# Print results for each node:

for n in NodeList
    NodeNumberTempB = parse(Int,n)
    print("\nNode "*n*":")
    
    InputsDictionary = Dict[] # reset the inputs dictionary to an empty dictionary before redefining

    for n in InputsList
        if n["Site"]["node"] == NodeNumberTempB
            InputsDictionary = n
        end
    end
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
            print("\n  Battery power (kW): "*format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kw"], digits =2), commas = true))
            print("\n    Battery capacity (kWh): "*format(round(results[NodeNumberTempB]["ElectricStorage"]["size_kwh"], digits =2), commas = true))
            print("\n    Average Battery SOC (fraction): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
            print("\n      Minimum Battery SOC (fraction): "*format(round(minimum(results[NodeNumberTempB]["ElectricStorage"]["soc_series_fraction"]), digits =2)))
            print("\n    Average battery to load (kW): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
            print("\n      Maximum battery to load (kW): "*format(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_load_series_kw"]), digits =2)))
            print("\n    Average battery to grid (kW): "*format(round(mean(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
            print("\n      Maximum battery to grid (kW): "*format(round(maximum(results[NodeNumberTempB]["ElectricStorage"]["storage_to_grid_series_kw"]), digits =2)))
        else
            print("\n  No battery")
        end
    else
        print("\n  No battery")
    end 
end 

print("\n----") 

# This code is for building the input dictionary for the microgrid outage simulator:

# Initiate the dictionary with data from the first node
if "ElectricStorage" in keys(results[parse(Int,NodeList[1])])
    if length(results[parse(Int,NodeList[1])]["ElectricStorage"]["soc_series_fraction"]) > 0
        BatteryChargekwh = results[parse(Int,NodeList[1])]["ElectricStorage"]["soc_series_fraction"]*results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kwh"]
        Batterykw = results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kw"]
        Batterykwh = results[parse(Int,NodeList[1])]["ElectricStorage"]["size_kwh"]
    else
        BatteryChargekwh = 0*ones(8760)
        Batterykw = 0
        Batterykwh = 0
    end 
else
    BatteryChargekwh = 0*ones(8760)
    Batterykw = 0
    Batterykwh = 0
end 

if "PV" in keys(results[parse(Int,NodeList[1])])
    PVProductionProfile_results = round.(((results[parse(Int,NodeList[1])]["PV"]["production_factor_series"].data)*results[parse(Int,NodeList[1])]["PV"]["size_kw"]), digits = 3)
else
    PVProductionProfile_results = zeros(8760)
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

DataDictionaryForEachNode = Dict([
    (NodeList[1],Dict([
        ("loads_kw", results[parse(Int,NodeList[1])]["ElectricLoad"]["load_series_kw"] ), 
        ("PVproductionprofile",  PVProductionProfile_results ),
        ("GeneratorSize", GeneratorSize_results),
        ("Battery_charge_kwh",  BatteryChargekwh),
        ("Battery_kw", Batterykw),
        ("Battery_kwh", Batterykwh),
        ("Fuel_tank_capacity_gal", GeneratorFuelGallonAvailable),
        #("time_steps_per_hour", 1), # Inputs_node1["Settings"]["time_steps_per_hour"]),
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
            BatteryChargekwh_B = 0*ones(8760)
            Batterykw_B = 0
            Batterykwh_B = 0  
        end      
    else 
        BatteryChargekwh_B = 0*ones(8760)
        Batterykw_B = 0
        Batterykwh_B = 0
    end
    if "PV" in keys(results[parse(Int,NodeList[i])])
        PVProductionProfile_results_B = round.(((results[parse(Int,NodeList[i])]["PV"]["production_factor_series"].data)*results[parse(Int,NodeList[i])]["PV"]["size_kw"]), digits = 3)
    else
        PVProductionProfile_results_B = zeros(8760)
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
            ("loads_kw",  results[parse(Int,NodeList[i])]["ElectricLoad"]["load_series_kw"]),
            ("PVproductionprofile", PVProductionProfile_results_B),
            ("GeneratorSize", GeneratorSize_results_B),
            ("Battery_charge_kwh", BatteryChargekwh_B),
            ("Battery_kw", Batterykw_B),
            ("Battery_kwh", Batterykwh_B),
            ("Fuel_tank_capacity_gal", GeneratorFuelGallonAvailable),
            #("time_steps_per_hour", 1),
            ("battery_roundtrip_efficiency",0.95)
            ])),
    ]) 

merge!(DataDictionaryForEachNode, DictionaryToAdd)

end 

return DataDictionaryForEachNode, Dictionary_LineFlow_Power_Series, Dictionary_Node_Data_Series, ldf_inputs, results

end 

# Use the function below to run the outage simulator 

function Microgrid_OutageSimulator(DataDictionaryForEachNode; NumberOfOutagesToTest = 15, ldf_inputs_dictionary = ldf_inputs_dictionary, TimeStepsPerHour_input = 1, OutageLength_TimeSteps_Input = 1)
    #MultiNode_OutageSimulator(DataDictionaryForEachNode; ldf_inputs_dictionary = ldf_inputs_dictionary, TimeStepsPerHour_input = 1, OutageLength_TimeSteps_Input = 1)
    #NumberOfOutagesToTest = 15
    #TimeStepsPerHour_input = 1
    #OutageLength_TimeSteps_Input = 1

NodeList = collect(keys(ldf_inputs_dictionary["load_nodes"]))

OutageLength_TimeSteps = OutageLength_TimeSteps_Input 
MaximumTimeStepToEvaluate_limit = ldf_inputs_dictionary["T"]-(OutageLength_TimeSteps+1) # T is the number of timesteps

if MaximumTimeStepToEvaluate_limit < NumberOfOutagesToTest
    print("\n  The number of possible outages to test is less than the number of outages requested by the user. $(MaximumTimeStepToEvaluate) will be evaluated instead of $(NumberOfOutagesToTest).")
    MaximumTimeStepToEvaluate = MaximumTimeStepToEvaluate_limit
else
    MaximumTimeStepToEvaluate = NumberOfOutagesToTest
end

RunNumber = 0
SuccessfullySolved = 0
    print("\n Number of outages to evaluate: "*string(MaximumTimeStepToEvaluate))

ldf_inputs_new = LinDistFlow.Inputs(
    ldf_inputs_dictionary["LinesFileLocation"],
    #joinpath("data", "singlephase38lines", "master.dss"), 
    ldf_inputs_dictionary["SubstationLocation"], # this is the location of the substation bus (aka, where the power is being input into the network)
    ldf_inputs_dictionary["LineCodesFileLocation"];
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
    Ntimesteps = OutageLength_TimeSteps,
    regulators = ldf_inputs_dictionary["VoltageRegulatorDictionary"]

)

# Define the outage start time steps based on the number of outages

IncrementSize_ForOutageStartTimes = Int(floor(MaximumTimeStepToEvaluate_limit/NumberOfOutagesToTest))

index = 0
for x in 1:MaximumTimeStepToEvaluate

    i = Int(x*IncrementSize_ForOutageStartTimes)

    m_outagesimulator = Model(Xpress.Optimizer)

    # Generate the LinDistFlow constraints
    LinDistFlow.add_variables(m_outagesimulator, ldf_inputs_new)
    LinDistFlow.constrain_power_balance(m_outagesimulator, ldf_inputs_new)
    LinDistFlow.constrain_substation_voltage(m_outagesimulator, ldf_inputs_new)
    LinDistFlow.constrain_KVL(m_outagesimulator, ldf_inputs_new)
    LinDistFlow.constrain_bounds(m_outagesimulator, ldf_inputs_new)
  
    print("\n *********************")
    print("\n Outage Simulation Run # "*string(x)*"  of  "*string(MaximumTimeStepToEvaluate)*" runs")
    print("\n *********************")
    print("\n ")
    
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
        
    LinDistFlow.constrain_loads(m_outagesimulator, ldf_inputs_new, ps) 

    # prevent power from entering the microgrid (to represent a power outage)
    JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ]["0-15",t] .>= 0 ) 
    JuMP.@constraint(m_outagesimulator, [t in 1:OutageLength_TimeSteps], m_outagesimulator[:Pᵢⱼ]["0-15",t] .<= 0.001)

    
    # determine all of the nodes with PV
    NodesWithPV = []
    for p in NodeList 
        if maximum(DataDictionaryForEachNode[p]["PVproductionprofile"]) > 0
            push!(NodesWithPV, p)
        end
    end 

    # Objective function:
        # The objective function maximizes the PV power that is used to meet the load
    @objective(m_outagesimulator, Max, sum(sum(m_outagesimulator[Symbol(string("dvPVToLoad_", n))]) for n in NodesWithPV))

    #=
    @objective(m_outagesimulator, Max,  (sum(m_outagesimulator[Symbol("dvPVToLoad_3")])) + 
                                        #(sum(m_outagesimulator[Symbol("dvPVToLoad_4")])) + 
                                        (sum(m_outagesimulator[Symbol("dvPVToLoad_6")])) + 
                                        (sum(m_outagesimulator[Symbol("dvPVToLoad_10")])) 
                                        #- round(1000*sum(value.(a[:Pᵢⱼ])),digits = 1)
                                        
                                        #(sum(m_outagesimulator[Symbol("dvPVToBat_3")])) +
                                        #(sum(m_outagesimulator[Symbol("dvPVToBat_4")])) +
                                        #(sum(m_outagesimulator[Symbol("dvPVToBat_6")])) +
                                        #(sum(m_outagesimulator[Symbol("dvPVToBat_10")]))
                                        ) # + sum(m_outagesimulator[Symbol("FuelUsage_4")])  )
    #@objective(m_outagesimulator, Max, sum(m_outagesimulator[Symbol("dvGenToLoad_3")]) + sum(m_outagesimulator[Symbol("dvGenToLoad_4")])) #  
    =#
    
    runresults = optimize!(m_outagesimulator)
    print("\n The result from run #"*string(i)*" is: "*string(termination_status(m_outagesimulator)))

    if string(termination_status(m_outagesimulator)) == "OPTIMAL"
        SuccessfullySolved = SuccessfullySolved + 1

        # TODO: inputs in to the microgrid_inputs for when to plot the outage results
        # Display plots for certain time steps 
        if i > 3000 && i < 3010
            print("\n the fuel left is: "*string(value.(m_outagesimulator[Symbol("FuelLeft_3")]) +
            #value.(m_outagesimulator[Symbol("FuelLeft_4")]) +
            value.(m_outagesimulator[Symbol("FuelLeft_6")]) +
            value.(m_outagesimulator[Symbol("FuelLeft_10")])) * " gal")

            # plot the dispatch for each of the REopt nodes for the outage that is being tested
            for n in NodeList
                Plots.plot(value.(m_outagesimulator[Symbol("dvPVToLoad_"*n)]), label = "PV to Load", linewidth = 3)
                Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToLoad_"*n)]), label = "Gen to Load", linewidth = 3)
                Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load", linewidth = 3)
                Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToLoad_"*n)]), label = "Grid to Load", linewidth = 3)
                Plots.plot!(DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps-1)], label = "Total Load", linecolor = (:black)) # line = (:dash), linewidth = 1)
                Plots.xlabel!("Time Step") 
                Plots.ylabel!("Power (kW)") 
                #Plots.xlims!(50,100) 
                display(Plots.title!("Node "*n*": Load Balance, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            end 
        
            #=
            Plots.plot(value.(m_outagesimulator[:dvPVToLoad_4]), label = "PV to Load")
            Plots.plot!(value.(m_outagesimulator[:dvGenToLoad_4]), label = "Gen to Load")
            Plots.plot!(value.(m_outagesimulator[:dvBatToLoad_4]), label = "Battery to Load")
            Plots.plot!(value.(m_outagesimulator[:dvGridToLoad_4]), label = "Grid to Load")
            Plots.plot!(DataDictionaryForEachNode["4"]["loads_kw"][i:(i+OutageLength_TimeSteps-1)], label = "Total Load", line = (:dash))
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Power (kW)")
            #Plots.xlims!(50,100)
            display(Plots.title!("Node 4: Load Balance, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            =#
            # Power Export
            for n in NodeList
                Plots.plot(value.(m_outagesimulator[Symbol("dvPVToGrid_"*n)]), label = "PV to Grid")
                Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToGrid_"*n)]), label = "Gen to Grid")
                Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
                Plots.xlabel!("Time Step")
                Plots.ylabel!("Power (kW)")
                #Plots.xlims!(50,100)
                display(Plots.title!("Node "*n*": Power Export, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            end
            # TODO: switch the 3 to a variable for a node
            # plot the battery flows for a couple days
            Plots.plot(-value.(m_outagesimulator[:dvBatToLoad_3]), label = "Battery to Load")
            Plots.plot!(-value.(m_outagesimulator[:dvBatToGrid_3]), label = "Battery to Grid")
            Plots.plot!(value.(m_outagesimulator[:dvGridToBat_3]), label = "Grid to Battery")
            Plots.plot!(value.(m_outagesimulator[:dvPVToBat_3]), label = "PV to Battery")
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Power (kW)")
            #Plots.xlims!(50,100)
            #Plots.ylims!(-28,28)
            display(Plots.title!("Node 3: Battery Flows, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))

            # Plot the Battery Charge:
            Plots.plot(value.(m_outagesimulator[:BatteryCharge_3]), label = "Battery Charge")
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Charge (kWh)")
            #Plots.ylims!(-3,3)
            #Plots.xlims!(50,100)
            display(Plots.title!("Node 3: Battery Charge, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            #=
            # Power Export
            Plots.plot(value.(m_outagesimulator[:dvPVToGrid_4]), label = "PV to Grid")
            Plots.plot!(value.(m_outagesimulator[:dvGenToGrid_4]), label = "Gen to Grid")
            Plots.plot!(value.(m_outagesimulator[:dvBatToGrid_4]), label = "Battery to Grid") 
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Power (kW)")
            #Plots.xlims!(50,100)
            display(Plots.title!("Node 4: Power Export, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            
            # Plot the Battery Charge:
            Plots.plot(value.(m_outagesimulator[:BatteryCharge_4]), label = "Battery Charge")
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Charge (kWh)")
            #Plots.ylims!(-3,3)
            #Plots.xlims!(50,100)
            display(Plots.title!("Node 4: Battery Charge, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))

            # plot the battery flows for a couple days
            Plots.plot(-value.(m_outagesimulator[:dvBatToLoad_4]), label = "Battery to Load")
            Plots.plot!(-value.(m_outagesimulator[:dvBatToGrid_4]), label = "Battery to Grid")
            Plots.plot!(value.(m_outagesimulator[:dvGridToBat_4]), label = "Grid to Battery")
            Plots.plot!(value.(m_outagesimulator[:dvPVToBat_4]), label = "PV to Battery")
            Plots.xlabel!("Time Step")
            Plots.ylabel!("Power (kW)")
            #Plots.xlims!(50,100)
            #Plots.ylims!(-28,28)
            display(Plots.title!("Node 4: Battery Flows, outage "*string(i)*" of "*string(MaximumTimeStepToEvaluate)))
            =#
        end 

    end 

    print("\n  Outages survived so far: "*string(SuccessfullySolved))
    print("\n  Outages tested so far: "*string(i)) 
    print("\n")
    #For debugging (to not cycle through all possible outage times)
    #if i > 15
    #    return m_outagesimulator
    #end
end 

RunNumber = MaximumTimeStepToEvaluate 
PercentOfOutagesSurvived = 100*(SuccessfullySolved/RunNumber)
print("\n The length of outage tested is: "*string(OutageLength_TimeSteps)*" time steps")
print("\n The number of outages survived is: "*string(SuccessfullySolved)*"  of  "*string(RunNumber)*" runs")
print("\n Percent of outages survived: "*string(round(PercentOfOutagesSurvived, digits = 2))*" %")
# SECTION 2: Run just the LinDistFlow package

return OutageLength_TimeSteps, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived

end 

# end of the Multinode Outage Simulator function**************************************************


# Function to run OpenDSS as a post processor for the data

function RunOpenDSS(REoptresults, Microgrid_Inputs)
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

