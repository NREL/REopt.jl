# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

#const PMD = PowerModelsDistribution

function run_outage_simulator(DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp, LineInfo_PMD)
    
    Outage_Results = Dict([])
    outage_simulator_time_start = now()

    # TODO: Transfer any line and transformer upgrades from the main optimization model into the outage simulator
    #line_max_amps = "N/A"
    #lines_rmatrix= "N/A"
    #lines_xmatrix= "N/A"
    #lines_for_upgrades= "N/A"
    #line_upgrades_each_line= "N/A"
    #all_lines= "N/A"
    #transformer_max_kva= "N/A"
    
    single_model_outage_simulator = "empty"
    for i in 1:length(Microgrid_Inputs.length_of_simulated_outages_time_steps)
        OutageLength = Microgrid_Inputs.length_of_simulated_outages_time_steps[i]
        OutageLength_TimeSteps_Input, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived, single_model_outage_simulator, outage_survival_results, outage_start_timesteps = Microgrid_OutageSimulator(DataDictionaryForEachNode, 
                                                                                                                                                                                                    REopt_dictionary, 
                                                                                                                                                                                                    Microgrid_Inputs, 
                                                                                                                                                                                                    TimeStamp;
                                                                                                                                                                                                    LineInfo_PMD = LineInfo_PMD,
                                                                                                                                                                                                    NumberOfOutagesToTest = Microgrid_Inputs.number_of_outages_to_simulate, 
                                                                                                                                                                                                    OutageLength_TimeSteps_Input = OutageLength)
        Outage_Results["$(OutageLength_TimeSteps_Input)_timesteps_outage"] = Dict(["PercentSurvived" => PercentOfOutagesSurvived, 
                                                                             "NumberOfRuns" => RunNumber, 
                                                                             "NumberOfOutagesSurvived" => SuccessfullySolved, 
                                                                             "outage_survival_results_each_timestep" => outage_survival_results,
                                                                             "outage_start_timesteps" => outage_start_timesteps ])
    
                                                                            end
    outage_simulator_time_milliseconds = CalculateComputationTime(outage_simulator_time_start)
    return Outage_Results, single_model_outage_simulator, outage_simulator_time_milliseconds
end


function Microgrid_OutageSimulator(DataDictionaryForEachNode, REopt_dictionary, Microgrid_Inputs, TimeStamp;
                                   NumberOfOutagesToTest = 15, OutageLength_TimeSteps_Input = 1, LineInfo_PMD="")
    # This function runs the outage simulator for a particular outage length
    
    # Initialize variables prior to running the simulator:
    NodeList = string.(GenerateREoptNodesList(Microgrid_Inputs))
    NodesWithPV = DetermineNodesWithPV(DataDictionaryForEachNode, NodeList)
    m_outagesimulator = ""
    RunNumber = 0
    OutageSimulator_LineFromSubstationToFacilityMeter, RunNumber, outage_start_timesteps_checked = PrepareInputsForOutageSimulator(Microgrid_Inputs, OutageLength_TimeSteps_Input, NumberOfOutagesToTest)
    RunsTested = 0
    outage_survival_results = -1 * ones(RunNumber)
    SuccessfullySolved = 0
    
    for x in 1:RunNumber
        print("\n Outage Simulation Run # "*string(x)*"  of  "*string(RunNumber)*" runs")
        RunsTested = RunsTested + 1
        i = outage_start_timesteps_checked[x]
        TotalTimeSteps = 8760*Microgrid_Inputs.time_steps_per_hour   

        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            if x != 1
                m_outagesimulator = "" # empty the m_outagesimulator variable
            end
            pm, data_math_mn, data_eng = Create_PMD_Model_For_REopt_Integration(Microgrid_Inputs, OutageLength_TimeSteps_Input)
            m_outagesimulator = pm.model # TODO: Confirm that when make changes to pm.model again in the function, that that version of pm.model has the additional constraints defined below for m_outagesimulator
        end
        
        for n in NodeList
            TimeSteps = OutageLength_TimeSteps_Input
            AddVariablesOutageSimulator(pm.model, TimeSteps, DataDictionaryForEachNode, n)           
            AddConstraintsOutageSimulator(Microgrid_Inputs, pm.model, TimeSteps, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, n, i)
        end 
        
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            Connect_To_PMD_Model(pm, Microgrid_Inputs, data_math_mn, OutageLength_TimeSteps_Input, LineInfo_PMD)
        end

        @objective(pm.model, Max, sum(sum(pm.model[Symbol(string("dvPVToLoad_", n))]) for n in NodesWithPV)) # The objective is to maximize the PV power that is used to meet the load
        
        if Microgrid_Inputs.model_type == "PowerModelsDistribution"
            PrepareOptimizer(pm, Microgrid_Inputs)
            results = PMD.optimize_model!(pm) 
            TerminationStatus = string(results["termination_status"])
            print("\n The result from run #"*string(RunsTested)*" is: "*TerminationStatus)
        end
        outage_survival_results[x], SuccessfullySolved = InterpretResult(TerminationStatus, SuccessfullySolved, Microgrid_Inputs, x, i, pm.model, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, TimeStamp, TotalTimeSteps, NodeList)
        print("\n  Outages survived so far: "*string(SuccessfullySolved)*", Outages tested so far: "*string(RunsTested))
    end

    PercentOfOutagesSurvived = DisplayResultsSummary(SuccessfullySolved, RunNumber, OutageLength_TimeSteps_Input)
        
    if Microgrid_Inputs.generate_results_plots          
        MapOutageSimulatorResultsPlots(Microgrid_Inputs, outage_survival_results, outage_start_timesteps_checked, TimeStamp, OutageLength_TimeSteps_Input)
    end

    return OutageLength_TimeSteps_Input, SuccessfullySolved, RunNumber, PercentOfOutagesSurvived, m_outagesimulator, outage_survival_results, outage_start_timesteps_checked
end 


function AddVariablesOutageSimulator(m_outagesimulator, TimeSteps, DataDictionaryForEachNode, n)

    Batterykw = DataDictionaryForEachNode[n]["Battery_kw"]
    
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

    dv = "dvGridToBat_"*n 
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0, upper_bound = Batterykw)
    dv = "dvGridToLoad_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
    dv = "dvGridPurchase_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)    
    dv = "dvTotalGridPurchase_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0 )

    dv = "FuelUsage_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
    dv = "TotalFuelUsage_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0)
    dv = "FuelLeft_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, base_name = dv, lower_bound = 0)

    dv = "BatteryCharge_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv) 
    dv = "SumOfBatFlows_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv)
    dv = "Binary_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, Bin)

    dv = "TotalExport_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name=dv) #, lower_bound = 0)
    
    dv = "dvPVToGrid_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
    dv = "dvBatToGrid_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)
    dv = "dvBatToGridWithEfficiency_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0) 
    dv = "dvGenToGrid_"*n
    m_outagesimulator[Symbol(dv)] = @variable(m_outagesimulator, [1:TimeSteps], base_name = dv, lower_bound = 0)

end


function AddConstraintsOutageSimulator(Microgrid_Inputs, m_outagesimulator, TimeSteps, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, n, i)

    GenPowerRating = DataDictionaryForEachNode[n]["GeneratorSize"]  
    time_steps_per_hour = Microgrid_Inputs.time_steps_per_hour
    GalPerkwh = 0.02457 # for the generator 
    FuelTankCapacity =  DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"]
    
    BatteryChargeStart = DataDictionaryForEachNode[n]["Battery_charge_kwh"][i]
    Batterykw = DataDictionaryForEachNode[n]["Battery_kw"]
    Batterykwh = DataDictionaryForEachNode[n]["Battery_kwh"]
    BatteryRoundTripEfficiencyFraction = DataDictionaryForEachNode[n]["battery_roundtrip_efficiency"]

    # Total power export:    
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], (m_outagesimulator[Symbol("TotalExport_"*n)] .== m_outagesimulator[Symbol("dvPVToGrid_"*n)][ts] + 
                                                                                            m_outagesimulator[Symbol("dvBatToGridWithEfficiency_"*n)][ts] + 
                                                                                            m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts]))

    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvBatToLoadWithEfficiency_"*n)][ts] .== m_outagesimulator[Symbol("dvBatToLoad_"*n)][ts] * BatteryRoundTripEfficiencyFraction)
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvBatToGridWithEfficiency_"*n)][ts] .== m_outagesimulator[Symbol("dvBatToGrid_"*n)][ts] * BatteryRoundTripEfficiencyFraction)

    # Total PV power constraint:
    PVProductionProfile = DataDictionaryForEachNode[n]["PVproductionprofile"]
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvPVToGrid_"*n)][ts] + 
                                                        m_outagesimulator[Symbol("dvPVToBat_"*n)][ts] + 
                                                        m_outagesimulator[Symbol("dvPVToLoad_"*n)][ts] .<= PVProductionProfile[i.+ts.-1] )
        
    # Grid power import to each node:           
    @constraint(m_outagesimulator, m_outagesimulator[Symbol("dvTotalGridPurchase_"*n)] .== sum(m_outagesimulator[Symbol("dvGridPurchase_"*n)]) )
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvGridPurchase_"*n)] .== 
                                                        m_outagesimulator[Symbol("dvGridToLoad_"*n)][ts] + m_outagesimulator[Symbol("dvGridToBat_"*n)][ts] )
    
    # Generator constraints:            
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts] + 
                                                        m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts] .<= 
                                                        GenPowerRating ) 
    @constraint(m_outagesimulator, m_outagesimulator[Symbol("TotalFuelUsage_"*n)] .== sum(m_outagesimulator[Symbol("FuelUsage_"*n)]) )
    @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("FuelUsage_"*n)][ts] .== (m_outagesimulator[Symbol("dvGenToGrid_"*n)][ts] + m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts])*(1/time_steps_per_hour)*GalPerkwh)
    @constraint(m_outagesimulator, sum(m_outagesimulator[Symbol("FuelUsage_"*n)]) .<= DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"] )
    @constraint(m_outagesimulator, m_outagesimulator[Symbol("FuelLeft_"*n)] == DataDictionaryForEachNode[n]["Fuel_tank_capacity_gal"]  - m_outagesimulator[Symbol("TotalFuelUsage_"*n)] )
        
    # Battery constraints:
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
    
    if string(Microgrid_Inputs.optimizer) == "Xpress.Optimizer" # only apply the indicator constraints if using a solver that is compatible with indicator constraints
        # Use a binary to prohibit charging and discharging at the same time:
        for t in 1:TimeSteps
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvGridToBat_"*n)][ts] .== 0.0} )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvPVToBat_"*n)][ts] .== 0.0} )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], !m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvBatToLoad_"*n)][ts] .== 0.0} )
            @constraint(m_outagesimulator, [ts in [1:TimeSteps]], !m_outagesimulator[Symbol("Binary_"*n)][ts] .=> {m_outagesimulator[Symbol("dvBatToGrid_"*n)][ts] .== 0.0} )
        end      
    else
        @warn "The battery may charge and discharge at the same time in the outage simulator because the solver is not compatible with indicator constraints."
    end

    # Power Balance at each node:
    @constraint(m_outagesimulator, [ts in [1:OutageLength_TimeSteps_Input]], m_outagesimulator[Symbol("dvPVToLoad_"*n)][ts] + 
                                                    m_outagesimulator[Symbol("dvGridToLoad_"*n)][ts] +
                                                    m_outagesimulator[Symbol("dvBatToLoadWithEfficiency_"*n)][ts] + 
                                                    m_outagesimulator[Symbol("dvGenToLoad_"*n)][ts] .== (DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps_Input-1)])[ts])
end


function Connect_To_PMD_Model(pm, Microgrid_Inputs, data_math_mn, OutageLength_TimeSteps_Input, LineInfo_PMD)
    # Link the power export decision variables to the PMD model
    outage_timesteps = collect(1:OutageLength_TimeSteps_Input)

    REopt_nodes = REopt.GenerateREoptNodesList(Microgrid_Inputs)

    gen_name2ind = Dict(gen["name"] => gen["index"] for (_,gen) in data_math_mn["nw"]["1"]["gen"])
    REopt_gen_ind_e = [gen_name2ind["REopt_gen_$e"] for e in REopt_nodes]
    
    PMD_Pg_ek = [PMD.var(pm, k, :pg, e).data[1] for e in REopt_gen_ind_e, k in outage_timesteps] 
    PMD_Qg_ek = [PMD.var(pm, k, :qg, e).data[1] for e in REopt_gen_ind_e, k in outage_timesteps]
                   
    for e in REopt_gen_ind_e  #Note: the REopt_gen_ind_e does not contain the facility meter
        JuMP.@constraint(pm.model, [k in outage_timesteps],  
                            PMD_Pg_ek[e,k] == pm.model[Symbol("TotalExport_"*string(REopt_nodes[e]))][k] - pm.model[Symbol("dvGridPurchase_"*string(REopt_nodes[e]))][k]   # negative power "generation" is a load
        )
        # TODO: add reactive power to the REopt nodes
        JuMP.@constraint(pm.model, [k in outage_timesteps],
                            PMD_Qg_ek[e,k] == 0.0 #m[Symbol("TotalExport_"*string(REopt_nodes[e]))][k] - m[Symbol("dvGridPurchase_"*string(REopt_nodes[e]))][k] 
        )
    end

    # Prevent power from entering the microgrid to simulate a power outage
    for PMD_time_step in outage_timesteps
        substation_line_index = LineInfo_PMD[Microgrid_Inputs.substation_line]["index"]
        timestep_for_network_data = 1 # collect the network configuration information from timestep 1, which assumes that the network is not changing (fair to assume with the REopt integration)
        branch = ref(pm, timestep_for_network_data, :branch, substation_line_index)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_connections = branch["f_connections"]
        t_connections = branch["t_connections"]
        f_idx = (substation_line_index, f_bus, t_bus)
        t_idx = (substation_line_index, t_bus, f_bus)

        p_fr = [PMD.var(pm, PMD_time_step, :p, f_idx)[c] for c in f_connections]
        p_to = [PMD.var(pm, PMD_time_step, :p, t_idx)[c] for c in t_connections]

        q_fr = [PMD.var(pm, PMD_time_step, :q, f_idx)[c] for c in f_connections]
        q_to = [PMD.var(pm, PMD_time_step, :q, t_idx)[c] for c in t_connections]

        JuMP.@constraint(pm.model, p_fr .== 0)  # The _fr and _to variables are just indicating power flow in either direction on the line. In PMD, there is a constraint that requires  p_to = -p_fr 
        JuMP.@constraint(pm.model, p_to .== 0)  # TODO test removing the "fr" constraints here in order to reduce the # of constraints in the model
        JuMP.@constraint(pm.model, q_fr .== 0)
        JuMP.@constraint(pm.model, q_to .== 0)
    end
end


function GenerateInputsForOutageSimulator(Microgrid_Inputs, REopt_results)
    results = REopt_results
                        
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
return DataDictionaryForEachNode
end


function PrepareInputsForOutageSimulator(Microgrid_Inputs, OutageLength_TimeSteps_Input, NumberOfOutagesToTest)
    randomly_ordered_timesteps = RandomlyOrderedTimesteps() 
    if Microgrid_Inputs.time_steps_per_hour == 1
        outage_start_timesteps = randomly_ordered_timesteps["8760"]
    elseif Microgrid_Inputs.time_steps_per_hour == 2
        outage_start_timesteps = randomly_ordered_timesteps["17540"]
    elseif Microgrid_Inputs.time_steps_per_hour == 4
        outage_start_timesteps = randomly_ordered_timesteps["35040"]
    else
        throw(@error("The defined time steps per hour are currently not compatible with the outage simulator"))
    end
    
    NumberOfTimeSteps = Microgrid_Inputs.time_steps_per_hour * 8760
    RunNumber_limit = NumberOfTimeSteps - (OutageLength_TimeSteps_Input+1) 
    outage_start_timesteps_filtered = outage_start_timesteps[outage_start_timesteps .< RunNumber_limit]

    if RunNumber_limit < NumberOfOutagesToTest
        @warn "The number of possible outages to test is less than the number of outages requested by the user. $(RunNumber) will be evaluated instead of $(NumberOfOutagesToTest)."
        RunNumber = RunNumber_limit
    else
        RunNumber = NumberOfOutagesToTest
    end

    outage_start_timesteps_checked = outage_start_timesteps_filtered[1:RunNumber]
 
    if Microgrid_Inputs.model_type == "PowerModelsDistribution" 
        OutageSimulator_LineFromSubstationToFacilityMeter = Microgrid_Inputs.substation_node*"-"*Microgrid_Inputs.facility_meter_node
    end

    return OutageSimulator_LineFromSubstationToFacilityMeter, RunNumber, outage_start_timesteps_checked
end


function InterpretResult(TerminationStatus, SuccessfullySolved, Microgrid_Inputs, x, i, m_outagesimulator, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, TimeStamp, TotalTimeSteps, NodeList)
    if TerminationStatus == "OPTIMAL"
        SuccessfullySolved = SuccessfullySolved + 1
        outage_survival_result = 1 # a value of 1 indicates that the outage was survived

        # TODO: calculate the amount of generator fuel that remains, for example: RemainingFuel = value.(m_outagesimulator[Symbol("FuelLeft_3")]) + value.(m_outagesimulator[Symbol("FuelLeft_10")])
                
        if Microgrid_Inputs.generate_results_plots
            if x in Microgrid_Inputs.run_numbers_for_plotting_outage_simulator_results
                CreatePlotsForOutageSimulatorModel(Microgrid_Inputs, m_outagesimulator, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, TimeStamp, TotalTimeSteps, NodeList, x, i)
            end 
        end
    else
        outage_survival_result = 0 # a value of 0 indicates that the outage was not survived
    end 

    return outage_survival_result, SuccessfullySolved
end


function PrepareOptimizer(pm, Microgrid_Inputs)
    set_optimizer(pm.model, Microgrid_Inputs.optimizer) 
    
    if Microgrid_Inputs.optimizer == Xpress.Optimizer
        set_optimizer_attribute(pm.model, "MIPRELSTOP", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(pm.model, "OUTPUTLOG", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)
    elseif Microgrid_Inputs.optimizer == Gurobi.Optimizer
        set_optimizer_attribute(pm.model, "MIPGap", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(pm.model, "OutputFlag", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)  
        set_optimizer_attribute(pm.model, "LogToConsole", Microgrid_Inputs.log_solver_output_to_console ? 1 : 0)
    elseif Microgrid_Inputs.optimizer == HiGHS.Optimizer
        set_optimizer_attribute(pm.model, "mip_rel_gap", Microgrid_Inputs.optimizer_tolerance)
        set_optimizer_attribute(pm.model, "output_flag", false)
        set_optimizer_attribute(pm.model, "log_to_console", false)
    else
        @info "The solver's default tolerance and log settings are being used for the optimization"
    end

end


function DisplayResultsSummary(SuccessfullySolved, RunNumber, OutageLength_TimeSteps_Input)
    print("\n --- Summary of results ---")
    PercentOfOutagesSurvived = 100*(SuccessfullySolved/RunNumber)
    print("\n The length of outage tested is: "*string(OutageLength_TimeSteps_Input)*" time steps")
    print("\n The number of outages survived is: "*string(SuccessfullySolved)*"  of  "*string(RunNumber)*" runs")
    print("\n Percent of outages survived: "*string(round(PercentOfOutagesSurvived, digits = 2))*" % \n")
    return PercentOfOutagesSurvived
end


function DetermineNodesWithPV(DataDictionaryForEachNode, NodeList)
    # This function determines which nodes have PV
    NodesWithPV = []
    for p in NodeList 
        if maximum(DataDictionaryForEachNode[p]["PVproductionprofile"]) > 0
            push!(NodesWithPV, p)
        end
    end 
    return NodesWithPV
end


function CreatePlotsForOutageSimulatorModel(Microgrid_Inputs, m_outagesimulator, DataDictionaryForEachNode, OutageLength_TimeSteps_Input, TimeStamp, TotalTimeSteps, NodeList, x, i)
    # This function makes plots for each of the REopt nodes
    
    mkdir(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps_Input)_Simulation_Run_$(x)")
    
    for n in NodeList
        Plots.plot(value.(m_outagesimulator[Symbol("dvPVToLoad_"*n)]), label = "PV to Load", linewidth = 3)
        Plots.plot!(value.(m_outagesimulator[Symbol("dvGenToLoad_"*n)]), label = "Gen to Load", linewidth = 3)
        Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load", linewidth = 3)
        Plots.plot!(value.(m_outagesimulator[Symbol("dvBatToLoadWithEfficiency_"*n)]), label = "Battery to Load with Efficiency", linewidth = 3)
        Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToLoad_"*n)]), label = "Grid to Load", linewidth = 3)
        Plots.plot!(DataDictionaryForEachNode[n]["loads_kw"][i:(i+OutageLength_TimeSteps_Input-1)], label = "Total Load", linecolor = (:black), line = (:dash), linewidth = 3)
        Plots.xlabel!("Time Step") 
        Plots.ylabel!("Power (kW)") 
        display(Plots.title!("Node "*n*": Load Balance, outage timestep: "*string(i)*" of "*string(TotalTimeSteps)))
        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps_Input)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Load_Balance_"*TimeStamp*".png")
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
        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps_Input)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Power_Export_"*TimeStamp*".png")
    
        # Plot the battery flows
        Plots.plot(-value.(m_outagesimulator[Symbol("dvBatToLoad_"*n)]), label = "Battery to Load")
        Plots.plot!(-value.(m_outagesimulator[Symbol("dvBatToGrid_"*n)]), label = "Battery to Grid")
        Plots.plot!(value.(m_outagesimulator[Symbol("dvGridToBat_"*n)]), label = "Grid to Battery")
        Plots.plot!(value.(m_outagesimulator[Symbol("dvPVToBat_"*n)]), label = "PV to Battery")
        Plots.xlabel!("Time Step")
        Plots.ylabel!("Power (kW)")
        display(Plots.title!("Node "*n*": Battery Flows, outage "*string(i)*" of "*string(TotalTimeSteps)))
        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps_Input)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Flows_"*TimeStamp*".png")
    
        # Plot the battery charge:
        Plots.plot(value.(m_outagesimulator[Symbol("BatteryCharge_"*n)]), label = "Battery Charge")
        Plots.xlabel!("Time Step")
        Plots.ylabel!("Charge (kWh)")
        display(Plots.title!("Node "*n*": Battery Charge, outage "*string(i)*" of "*string(TotalTimeSteps)))
        Plots.savefig(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/OutageTimeStepsLength_$(OutageLength_TimeSteps_Input)_Simulation_Run_$(x)/Node_$(n)_Timestep_$(i)_Battery_Charge_"*TimeStamp*".png")
    end
end


function MapOutageSimulatorResultsPlots(Microgrid_Inputs, outage_survival_results, outage_start_timesteps, TimeStamp, OutageLength_TimeSteps_Input)
    # This function creates plots to summarize the outage simulation results

    indices_outage_survived = findall(x -> x==1, outage_survival_results) # Find indices of survived outages
    indices_outage_not_survived = findall(x -> x==0, outage_survival_results) # Find indices of non-survived outages

    outage_start_timesteps_survived = outage_start_timesteps[indices_outage_survived]
    outage_start_timesteps_not_survived = outage_start_timesteps[indices_outage_not_survived]

    time_of_day_survived = zeros(length(outage_start_timesteps_survived))
    day_of_year_survived = zeros(length(outage_start_timesteps_survived))
    time_of_day_not_survived = zeros(length(outage_start_timesteps_not_survived))
    day_of_year_not_survived = zeros(length(outage_start_timesteps_not_survived))

    for x in collect(1:length(outage_start_timesteps_survived))
        time_of_day_survived[x] = outage_start_timesteps_survived[x] % (24*Microgrid_Inputs.time_steps_per_hour)
        day_of_year_survived[x] = ceil(outage_start_timesteps_survived[x] / (24*Microgrid_Inputs.time_steps_per_hour))
    end

    for x in collect(1:length(outage_start_timesteps_not_survived))
        time_of_day_not_survived[x] = outage_start_timesteps_not_survived[x] % (24*Microgrid_Inputs.time_steps_per_hour)
        day_of_year_not_survived[x] = ceil(outage_start_timesteps_not_survived[x] / (24*Microgrid_Inputs.time_steps_per_hour))
    end        

    traces = PlotlyJS.GenericTrace[]
    push!(traces, PlotlyJS.histogram(x=time_of_day_survived, name="Survived", xbins_start=0, xbins_end=24, xbins_size=1))
    push!(traces, PlotlyJS.histogram(x=time_of_day_not_survived, name="Not Surived", xbins_start=0, xbins_end=24, xbins_size=1)) 
    layout = PlotlyJS.Layout(barmode="stack", title = "$(OutageLength_TimeSteps_Input) Time Step Outage: Distribution of Survival by time of day", xaxis_title = "Time of Day (hour)", yaxis_title="Count")
    p1 = PlotlyJS.plot(traces, layout)
    PlotlyJS.savefig(p1, Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/Outage_Survival_Histogram_By_Time_Of_Day_$(OutageLength_TimeSteps_Input)_Timestep_Outage.html")
    display(p1)
    
    traces = PlotlyJS.GenericTrace[]
    push!(traces, PlotlyJS.histogram(x=day_of_year_survived, name="Survived", xbins_start=0, xbins_end=371, xbins_size=7))
    push!(traces, PlotlyJS.histogram(x=day_of_year_not_survived, name="Not Surived", xbins_start=0, xbins_end=371, xbins_size=7)) 
    layout = PlotlyJS.Layout(barmode="stack", title = "$(OutageLength_TimeSteps_Input) Time Step Outage: Distribution of Survival by day of year", xaxis_title = "Day of Year (binned in weekly intervals)", yaxis_title="Count")
    p2 = PlotlyJS.plot(traces, layout)
    PlotlyJS.savefig(p2, Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots/Outage_Survival_Histogram_By_Day_Of_Year_$(OutageLength_TimeSteps_Input)_Timestep_Outage.html")
    display(p2)
end


function RandomlyOrderedTimesteps() 
    path = joinpath(dirname(pathof(REopt)))
    path = replace(path, "\\" => "/")
    randomly_ordered_timesteps = JSON.parsefile(path*"/microgrid/random_vectors.json")
    return randomly_ordered_timesteps
end


function CreateRandomVectorOrder(filepath, vector1, vector2, vector3)
    # This function saves a random ordering of vector data for the outage simulator
        #=
        # Use this code to create inputs into the function:
        vector_8760_ordered = collect(1:8760)
        vector_8760_randomly_unordered = Random.shuffle(vector_8760_ordered)
        
        vector_17540_ordered = collect(1:17540)
        vector_17540_randomly_unordered = Random.shuffle(vector_17540_ordered)
        
        vector_35040_ordered = collect(1:35040)
        vector_35040_randomly_unordered = Random.shuffle(vector_35040_ordered)

        CreateRandomVectorOrder(filepath, vector_8760_randomly_unordered, vector_17540_randomly_unordered, vector_35040_randomly_unordered
        =#

    vector_8760_randomly_unordered = vector1
    vector_17540_randomly_unordered = vector2
    vector_35040_randomly_unordered = vector3

    data = Dict(["8760" => vector_8760_randomly_unordered,
                 "17540" => vector_17540_randomly_unordered,
                 "35040" => vector_35040_randomly_unordered
                ])
    
    open(filepath*"/random_vectors.json", "w") do x
        JSON.print(x, data)
    end

    # Visualize some distributions of the data
    lengths = [100,250,500,1000]
    
    for length in lengths

        selected_values = vector_8760_randomly_unordered[1:length]
        time_of_day = zeros(length)
        day_of_year = zeros(length)
        for x in collect(1:length)
            time_of_day[x] = selected_values[x] % 24
            day_of_year[x] = ceil(selected_values[x] / 24)
        end
        Plots.histogram(time_of_day, bins=range(0,24, length=25))
        Plots.xlabel!("Hour of Day")
        Plots.ylabel!("Occurances")
        display(Plots.title!("Time of day distribution, $(length) tests"))
        Plots.histogram(day_of_year, bins=0:7:371)
        Plots.xlabel!("Day of Year")
        Plots.ylabel!("Occurances")
        display(Plots.title!("Day of year distribution, $(length) tests"))
    end
end


