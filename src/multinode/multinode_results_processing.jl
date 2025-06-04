# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

const PMD = PowerModelsDistribution

function CreateOutputsFolder(Multinode_Inputs, TimeStamp)
    # Create a folder for the outputs if saving results
    if Multinode_Inputs.generate_CSV_of_outputs == true || Multinode_Inputs.generate_results_plots == true
        @info "Creating a folder for the results"
        mkdir(Multinode_Inputs.folder_location*"/results_"*TimeStamp)
    end
    if (Multinode_Inputs.generate_results_plots == true) && (Multinode_Inputs.run_outage_simulator == true)
        mkdir(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/Outage_Simulation_Plots") 
    end
end


function CalculateComputationTime(StartTime)
    # Function to calculate the elapsed time between a time (input into the function) and the current time
    EndTime = now()
    ComputationTime_milliseconds = EndTime - StartTime
    #print("The computation time in milliseconds is: $(ComputationTime_milliseconds)")

    if Dates.value(ComputationTime_milliseconds) > 1000
        ComputationTime_minutes = round(Dates.value(ComputationTime_milliseconds)/60000, digits=2)
    else
        ComputationTime_minutes = round(Dates.value(ComputationTime_milliseconds)/60000, digits=4)
    end

    return ComputationTime_milliseconds, ComputationTime_minutes
end


function Results_Processing_REopt_PMD_Model(m, results, data_math_mn, REoptInputs_Combined, Multinode_Inputs, timestamp, time_results; allow_upgrades=false, line_upgrade_options_each_line ="", BAU_case=false)
    
    if BAU_case == true
        BAU_indicator = "BAU_model_"
    else
        BAU_indicator = ""
    end
    
    # Extract the PMD results
    print("\n Reading the PMD results")
    Start_reading_PMD_results = now()
    sol_math = results["solution"]
    # The PMD results are saved to the sol_eng variable
    sol_eng = transform_solution(sol_math, data_math_mn)
    milliseconds, time_results["Step $(length(keys(time_results))+1): "*BAU_indicator*"reading_PMD_results_minutes"] = CalculateComputationTime(Start_reading_PMD_results)

    # Extract the REopt results
    print("\n Reading the REopt results \n")
    Start_reading_REopt_results = now()
    REopt_results = reopt_results(m, REoptInputs_Combined)

    # Process the line upgrade results
    if allow_upgrades == true && Multinode_Inputs.model_line_upgrades == true
        line_upgrades = Process_Line_Upgrades(m, line_upgrade_options_each_line, Multinode_Inputs, timestamp)
    else
        line_upgrades = "N/A"
    end

    # Generate inputs that will be used for the multinode outage simulator
    if Multinode_Inputs.run_outage_simulator
        DataDictionaryForEachNodeForOutageSimulator = REopt.GenerateInputsForOutageSimulator(Multinode_Inputs, REopt_results)
    else
        DataDictionaryForEachNodeForOutageSimulator = "N/A"
    end

    if Multinode_Inputs.model_subtype == "LPUBFDiagPowerModel" 
        pf_name = "pf"
        qf_name = "qf"
    elseif Multinode_Inputs.model_subtype == "SOCNLPUBFPowerModel" 
        pf_name = "Pf"
        qf_name = "Qf"
    end

    # Compute values for each line and store line power flows in a dataframe and dictionary 
    DataLineFlow = zeros(7)
    DataFrame_LineFlow = DataFrame(fill(Any[],7), [:Line, :Minimum_LineFlow_ActivekW, :Maximum_LineFlow_ActivekW, :Average_LineFlow_ActivekW, :Minimum_LineFlow_ReactivekVAR, :Maximum_LineFlow_ReactivekVAR, :Average_LineFlow_ReactivekVAR ])
    PMD_Dictionary_LineFlow_Power_Series = Dict([])

    for line in keys(sol_eng["nw"]["1"]["line"]) # read all of the line names from the first time step
        ActivePowerFlow_line_temp = []
        ReactivePowerFlow_line_temp = []

        ActivePowerFlow_line_Phase1_temp = []
        ActivePowerFlow_line_Phase2_temp = []
        ActivePowerFlow_line_Phase3_temp = []
        ReactivePowerFlow_line_Phase1_temp = []
        ReactivePowerFlow_line_Phase2_temp = []
        ReactivePowerFlow_line_Phase3_temp = []

        for i in 1:length(sol_eng["nw"])
            push!(ActivePowerFlow_line_temp, sum(sol_eng["nw"][string(i)]["line"][line][pf_name][Phase] for Phase in keys(sol_eng["nw"][string(i)]["line"][line][pf_name])) ) # The "for Phase in keys(..." sums the power across the phases
            push!(ReactivePowerFlow_line_temp, sum(sol_eng["nw"][string(i)]["line"][line][qf_name][Phase] for Phase in keys(sol_eng["nw"][string(i)]["line"][line][qf_name])) )
        end

        # Pull data from the first time step
        for phase in keys(sol_eng["nw"]["1"]["line"][line][pf_name])  # TODO: confirm that "phase" here is the phase number, not just the index
            if phase == 1
                for i in 1:length(sol_eng["nw"])
                    push!(ActivePowerFlow_line_Phase1_temp, sol_eng["nw"][string(i)]["line"][line][pf_name][phase])
                    push!(ReactivePowerFlow_line_Phase1_temp, sol_eng["nw"][string(i)]["line"][line][qf_name][phase])
                end
            elseif phase == 2
                for i in 1:length(sol_eng["nw"])
                    push!(ActivePowerFlow_line_Phase2_temp, sol_eng["nw"][string(i)]["line"][line][pf_name][phase])
                    push!(ReactivePowerFlow_line_Phase2_temp, sol_eng["nw"][string(i)]["line"][line][qf_name][phase])
                end
            elseif phase ==3
                for i in 1:length(sol_eng["nw"])
                    push!(ActivePowerFlow_line_Phase3_temp, sol_eng["nw"][string(i)]["line"][line][pf_name][phase])
                    push!(ReactivePowerFlow_line_Phase3_temp, sol_eng["nw"][string(i)]["line"][line][qf_name][phase])
                end
            else
                throw(@error("The phase number, $(phase), is invalid"))
            end
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
        PMD_Dictionary_LineFlow_Power_Series_temp = Dict([(line, Dict([
                                                            ("ActiveLineFlow", ActivePowerFlow_line_temp),
                                                            ("ReactiveLineFlow", ReactivePowerFlow_line_temp),
                                                            ("Phase1_ActiveLineFlow", ActivePowerFlow_line_Phase1_temp),
                                                            ("Phase2_ActiveLineFlow", ActivePowerFlow_line_Phase2_temp),
                                                            ("Phase3_ActiveLineFlow", ActivePowerFlow_line_Phase3_temp),
                                                            ("Phase1_ReactiveLineFlow", ReactivePowerFlow_line_Phase1_temp),
                                                            ("Phase2_ReactiveLineFlow", ReactivePowerFlow_line_Phase2_temp),
                                                            ("Phase3_ReactiveLineFlow", ReactivePowerFlow_line_Phase3_temp)
                                                        ]))
                                                        ])
        merge!(PMD_Dictionary_LineFlow_Power_Series, PMD_Dictionary_LineFlow_Power_Series_temp)

    end

    # Record the time for post-processing
    milliseconds, time_results["Step $(length(keys(time_results))+1): "*BAU_indicator*"reading_REopt_results_minutes"] = CalculateComputationTime(Start_reading_REopt_results)

    return REopt_results, sol_eng, DataDictionaryForEachNodeForOutageSimulator, PMD_Dictionary_LineFlow_Power_Series, DataFrame_LineFlow, line_upgrades
end


function Process_Line_Upgrades(m, line_upgrade_options_each_line, Multinode_Inputs, TimeStamp)

    line_upgrade_results = DataFrame(fill(Any[], 4), [:Line, :Upgraded, :MaximumRatedAmps, :UpgradeCost])
    for line in keys(line_upgrade_options_each_line)
        number_of_entries = length(line_upgrade_options_each_line[line]["max_amperage"])
        dv = "Bin"*line
        maximum_amps = sum(value.(m[Symbol(dv)][i])*line_upgrade_options_each_line[line]["max_amperage"][i] for i in 1:number_of_entries)
        #rmatrix = sum(value.(m[Symbol(dv)][i])*line_upgrades_each_line[line]["rmatrix"][i] for i in 1:number_of_entries)
        #xmatrix = sum(value.(m[Symbol(dv)][i])*line_upgrades_each_line[line]["xmatrix"][i] for i in 1:number_of_entries)
        upgraded_cost = round(value.(m[Symbol("line_cost")][line]), digits = 0)

        if Int(round(value.(m[Symbol(dv)][1]), digits=0)) != 1
            upgraded = "Yes"
        else
            upgraded = "No"
        end

        line_upgrade_results_temp = DataFrame([line upgraded maximum_amps upgraded_cost ], [:Line, :Upgraded, :MaximumRatedAmps, :UpgradeCost])
        line_upgrade_results = append!(line_upgrade_results, line_upgrade_results_temp)
    end

    # Save line upgrade results to a csv 
    if Multinode_Inputs.generate_CSV_of_outputs
        CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Line_Upgrade_Summary_"*TimeStamp*".csv", line_upgrade_results)
    end

    return line_upgrade_results
end


function Results_Compilation(model, results, PMD_Results, Outage_Results, Multinode_Inputs, DataFrame_LineFlow_Summary, PMD_Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; all_line_powerflow_results="", simple_powerflow_model_results="", bau_model = "", system_results_BAU = "", line_upgrade_results = "", transformer_upgrade_results = "", outage_simulator_time = "")
    
    @info "Compiling the results"

    InputsList = Multinode_Inputs.REopt_inputs_list

    # Compute system-level outputs
    system_results = Dict{String, Any}() # Float64}()
    
    # Initialize the results variables
    total_lifecycle_capital_cost = 0 # includes replacements and incentives
    total_initial_capital_costs = 0
    total_initial_capital_costs_after_incentives = 0
    total_lifecycle_storage_capital_costs = 0
    line_upgrade_costs = 0
    total_PV_size_kw = 0
    total_PV_energy_produced_minus_curtailment_first_year = 0
    total_electric_storage_size_kw = 0
    total_electric_storage_size_kwh = 0
    total_generator_size_kw = 0

    for n in InputsList 
        node_temp = n["Site"]["node"]

        total_lifecycle_capital_cost = total_lifecycle_capital_cost + results[node_temp]["Financial"]["lifecycle_capital_costs"]
        total_initial_capital_costs = total_initial_capital_costs + results[node_temp]["Financial"]["initial_capital_costs"]
        total_initial_capital_costs_after_incentives = total_initial_capital_costs_after_incentives + results[node_temp]["Financial"]["initial_capital_costs_after_incentives"] 
        total_lifecycle_storage_capital_costs = total_lifecycle_storage_capital_costs + results[node_temp]["Financial"]["lifecycle_storage_capital_costs"]

        if "PV" in keys(results[node_temp])
            total_PV_size_kw = total_PV_size_kw + results[node_temp]["PV"]["size_kw"]
            total_PV_energy_produced_minus_curtailment_first_year = total_PV_energy_produced_minus_curtailment_first_year + 
                                                                    (results[node_temp]["PV"]["year_one_energy_produced_kwh"] - sum(results[node_temp]["PV"]["electric_curtailed_series_kw"]/Multinode_Inputs.time_steps_per_hour))
        end
        if "ElectricStorage" in keys(results[node_temp])
            total_electric_storage_size_kw = total_electric_storage_size_kw + results[node_temp]["ElectricStorage"]["size_kw"]
            total_electric_storage_size_kwh = total_electric_storage_size_kwh + results[node_temp]["ElectricStorage"]["size_kwh"]
        end
        if "Generator" in keys(results[node_temp])
            total_generator_size_kw = total_generator_size_kw + results[node_temp]["Generator"]["size_kw"]
        end
    end

    if Multinode_Inputs.model_line_upgrades
        line_upgrade_costs = value.(model[:total_line_upgrade_cost])
    else
        line_upgrade_costs = 0
    end

    system_results["total_lifecycle_cost"] = value.(model[Symbol("Costs")])
    system_results["total_lifecycle_capital_cost"] = total_lifecycle_capital_cost + line_upgrade_costs
    system_results["total_initial_capital_costs"] = total_initial_capital_costs + line_upgrade_costs
    system_results["total_initial_capital_costs_after_incentives"] =  total_initial_capital_costs_after_incentives + line_upgrade_costs # no incentives are modeled for line upgrades
    system_results["total_lifecycle_storage_capital_cost"] = total_lifecycle_storage_capital_costs
    system_results["total_line_upgrade_cost"] = line_upgrade_costs
    system_results["total_PV_size_kw"] = total_PV_size_kw
    system_results["total_PV_energy_produced_minus_curtailment_first_year"] = total_PV_energy_produced_minus_curtailment_first_year
    system_results["total_electric_storage_size_kw"] = total_electric_storage_size_kw
    system_results["total_electric_storage_size_kwh"] = total_electric_storage_size_kwh
    system_results["total_generator_size_kw"] = total_generator_size_kw
    
    if (system_results_BAU != "") && (system_results_BAU != "none")
        system_results["net_present_value"] = system_results_BAU["total_lifecycle_cost"] - value.(model[Symbol("Costs")])
    else
        system_results["net_present_value"] = "Not calculated"
    end

    DataFrame_BusVoltages_Summary, per_unit_voltages, minimum_voltage, average_voltage, maximum_voltage = VoltageResultsSummary(PMD_Results)

    # Generate a csv file with outputs from the model if the "generate_CSV_of_outputs" field is set to true
    if system_results_BAU != ""
        if Multinode_Inputs.generate_CSV_of_outputs == true
            @info "Generating CSV of outputs"
            DataLabels = []
            Data = []
            
            LineFromSubstationToFacilityMeter = "line"*Multinode_Inputs.substation_node * "_" * Multinode_Inputs.facilitymeter_node
            
            if Multinode_Inputs.model_type == "PowerModelsDistribution"

                PMD_MaximumPowerOnsubstation_line_ActivePower = (round(maximum(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))
                PMD_MinimumPowerOnsubstation_line_ActivePower = (round(minimum(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))
                PMD_AveragePowerOnsubstation_line_ActivePower = (round(mean(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ActiveLineFlow"]), digits = 0))

                PMD_MaximumPowerOnsubstation_line_ReactivePower = (round(maximum(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))
                PMD_MinimumPowerOnsubstation_line_ReactivePower = (round(minimum(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))
                PMD_AveragePowerOnsubstation_line_ReactivePower = (round(mean(PMD_Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["ReactiveLineFlow"]), digits = 0))
            end

            # Add system-level results

            push!(DataLabels, "----Optimization Parameters----")
            push!(Data,"")
            push!(DataLabels, "  Number of Variables")
            push!(Data, length(all_variables(model)))
            push!(DataLabels, "  Computation time, including the BAU model and the outage simulator if used (minutes)")
            push!(Data, round(ComputationTime_EntireModel, digits=2))
            push!(DataLabels, "  Model solve time (minutes)" )
            push!(Data, round(JuMP.solve_time(model)/60, digits = 2))
            
            if Multinode_Inputs.run_BAU_case 
                push!(DataLabels, "  BAU model solve time (minutes)" )
                push!(Data, round(JuMP.solve_time(bau_model)/60, digits = 2))
            end
            if Multinode_Inputs.run_outage_simulator
                push!(DataLabels, "  Total outage simulation time (minutes)")
                push!(Data, outage_simulator_time)
            end

            push!(DataLabels, "----Model Information----")
            push!(Data,"")
            push!(DataLabels,"  Number of Phases (input)")
            push!(Data, Multinode_Inputs.number_of_phases)
            push!(DataLabels,"  Multinode Type (input)")
            push!(Data, Multinode_Inputs.multinode_type)
            push!(DataLabels,"  Model Type (input)")
            push!(Data, Multinode_Inputs.model_type)
            push!(DataLabels,"  Model Subtype (input)")
            push!(Data, Multinode_Inputs.model_subtype)
            
            push!(DataLabels, "----Model Diagnostics----")
            push!(Data,"")
            if Multinode_Inputs.allow_bus_voltage_violations
                push!(DataLabels,"  Number of Bus Voltage Violations")
                push!(Data, sum(value.(model[Symbol("binBusVoltageViolation")]).data))
            else
                push!(DataLabels,"  No diagnostics were run")
                push!(Data, "")
            end
            
            push!(DataLabels, "----System Results----")
            push!(Data,"")
            push!(DataLabels,"  Total Lifecycle Cost (LCC)")
            push!(Data, round(system_results["total_lifecycle_cost"], digits=0))
            push!(DataLabels,"  Total Lifecycle Capital Cost (LCCC)")
            push!(Data, round(system_results["total_lifecycle_capital_cost"], digits=0))

            if Multinode_Inputs.run_BAU_case 
                push!(DataLabels,"  Net Present Value (NPV)")
                push!(Data, round(system_results["net_present_value"], digits=0))
            end

            push!(DataLabels,"  Total initial capital costs")
            push!(Data, round(system_results["total_initial_capital_costs"],digits=0))
            push!(DataLabels,"  Total initial capital costs after incentives")
            push!(Data, round(system_results["total_initial_capital_costs_after_incentives"],digits=0))

            push!(DataLabels,"  Total lifecycle storage capital cost")
            push!(Data, round(system_results["total_lifecycle_storage_capital_cost"],digits=0))
            push!(DataLabels,"  Total line upgrade costs")
            push!(Data, round(system_results["total_line_upgrade_cost"],digits=0))
            
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
            
            push!(DataLabels,"  Total Number of PMD timesteps, based on the user input")
            push!(Data, length(PMD_Results["nw"]) )

            if Multinode_Inputs.number_of_phases == 1
                push!(DataLabels,"  Minimum per unit bus voltage")
                push!(Data, minimum_voltage)
                push!(DataLabels,"  Average per unit bus voltage")
                push!(Data, average_voltage)
                push!(DataLabels,"  Maximum per unit bus voltage")
                push!(Data, maximum_voltage)
            else
                push!(DataLabels,"  Voltage post processing does not currently work for three-phase systems")
                push!(Data, "")
            end

            push!(DataLabels,"  From PMD: Maximum power flow on substation line, Active Power kW")
            push!(Data, PMD_MaximumPowerOnsubstation_line_ActivePower)
            push!(DataLabels,"  From PMD: Minimum power flow on substation line, Active Power kW")
            push!(Data, PMD_MinimumPowerOnsubstation_line_ActivePower)
            push!(DataLabels,"  From PMD: Average power flow on substation line, Active Power kW")
            push!(Data, PMD_AveragePowerOnsubstation_line_ActivePower)

            push!(DataLabels,"  From PMD: Maximum power flow on substation line, Reactive Power kVAR")
            push!(Data, PMD_MaximumPowerOnsubstation_line_ReactivePower)
            push!(DataLabels,"  From PMD: Minimum power flow on substation line, Reactive Power kVAR")
            push!(Data, PMD_MinimumPowerOnsubstation_line_ReactivePower)
            push!(DataLabels,"  From PMD: Average power flow on substation line, Reactive Power kVAR")
            push!(Data, PMD_AveragePowerOnsubstation_line_ReactivePower)
            
            if Multinode_Inputs.apply_simple_powerflow_model_to_timesteps_that_do_not_use_PMD
                push!(DataLabels,"  From Simple Powerflow Model: Maximum power flow on substation line, Active Power kW")
                push!(Data, round(maximum(simple_powerflow_model_results["lines"][LineFromSubstationToFacilityMeter]["line_power_flow_series"]),digits=0) )
                push!(DataLabels,"  From Simple Powerflow Model: Minimum power flow on substation line, Active Power kW")
                push!(Data, round(minimum(simple_powerflow_model_results["lines"][LineFromSubstationToFacilityMeter]["line_power_flow_series"]),digits=0))
                push!(DataLabels,"  From Simple Powerflow Model: Average power flow on substation line, Active Power kW")
                push!(Data, round(mean(simple_powerflow_model_results["lines"][LineFromSubstationToFacilityMeter]["line_power_flow_series"]),digits=0))
            end

            # Add the multinode outage results to the dataframe
            push!(DataLabels, "----Multinode Outage Simulator Results----")
            push!(Data, "")
            if Multinode_Inputs.run_outage_simulator == true
                push!(DataLabels, "  Allowed dropped load?")
                push!(Data, Multinode_Inputs.allow_dropped_load)
                for i in 1:length(Multinode_Inputs.length_of_simulated_outages_time_steps)
                    OutageLength = Multinode_Inputs.length_of_simulated_outages_time_steps[i]
                    push!(DataLabels, " --Outage Length: $(OutageLength) time steps--")
                    push!(Data, "")
                    push!(DataLabels, "  Percent of Outages Survived")
                    push!(Data, string(Outage_Results["$(OutageLength)_timesteps_outage"]["PercentSurvived"])*" %")
                    push!(DataLabels, "  Total Number of Outages Tested")
                    push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfRuns"])
                    push!(DataLabels, "  Total Number of Outages Survived")
                    push!(Data, Outage_Results["$(OutageLength)_timesteps_outage"]["NumberOfOutagesSurvived"])
                    if Multinode_Inputs.allow_dropped_load
                        push!(DataLabels, "  Average Load Met Fraction")
                        push!(Data, round(Outage_Results["$(OutageLength)_timesteps_outage"]["dropped_load_results"]["average_load_met_fraction"], digits=5))
                    end
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
            
            # Save the results summary dataframe as a csv document
            dataframe_results = DataFrame(Labels = DataLabels, Data = Data)
            CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Summary_"*TimeStamp*".csv", dataframe_results)
            
            # Save the Line Flow summary to a different csv
            CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/PMD_Results_Line_Powerflow_Summary_"*TimeStamp*".csv", DataFrame_LineFlow_Summary)
            
            # Save the bus voltage summary to a different csv
            CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/PMD_Results_Bus_Voltages_Summary_"*TimeStamp*".csv", DataFrame_BusVoltages_Summary)
            
            # Save the transformer upgrade results to a csv
            if Multinode_Inputs.model_transformer_upgrades
                CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Transformer_Upgrade_Summary_"*TimeStamp*".csv", dataframe_transformer_upgrade_summary)
            end
            
            # Generate CSV summarizing the line power flow for each line
            line_powerflow_data = DataFrame()
            
            line_powerflow_data[!,"REopt_time_steps"] = Multinode_Inputs.PMD_time_steps  # Note: The PMD_time_steps input is expressed in REopt time steps
            line_powerflow_data[!,"PMD_time_steps"] = collect(1:length(Multinode_Inputs.PMD_time_steps))
                                                
            for line_data in keys(PMD_Dictionary_LineFlow_Power_Series)
                for data_subtype in keys(PMD_Dictionary_LineFlow_Power_Series[line_data])
                    if (data_subtype == "ActiveLineFlow") || (data_subtype == "ReactiveLineFlow")
                        OptionalNameAddition = "CombinedPhases_"
                    else
                        OptionalNameAddition = ""
                    end
                    line_phase_name = line_data*"_"*OptionalNameAddition*data_subtype
                    
                    if length(PMD_Dictionary_LineFlow_Power_Series[line_data][data_subtype]) > 0
                        line_powerflow_data[!,line_phase_name] = PMD_Dictionary_LineFlow_Power_Series[line_data][data_subtype]
                    else
                        line_powerflow_data[!,line_phase_name] = zeros(length(Multinode_Inputs.PMD_time_steps))
                    end
                    
                end
            end
            
            line_powerflow_data = line_powerflow_data[:,sortperm(names(line_powerflow_data))] # Sort the dataframe by the header title

            CSV.write(Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/PMD_Results_Line_Powerflow_Data_"*TimeStamp*".csv", line_powerflow_data)
            
        end 

        #Display results if the "display_results" input is set to true
        if Multinode_Inputs.display_results == true
            print("\n-----")
            print("\nResults:") 
            print("\n   The computation time was: "*string(ComputationTime_EntireModel))
        
            print("Line Flow Results")
            display(DataFrame_LineFlow_Summary)
        
            print("\nSubstation data: ")
            print("\n   Maximum active power flow from substation, kW: "*string(PMD_MaximumPowerOnsubstation_line_ActivePower))
            print("\n   Minimum active power flow from substation, kW: "*string(PMD_MinimumPowerOnsubstation_line_ActivePower))
            print("\n   Average active power flow from substation, kW: "*string(PMD_AveragePowerOnsubstation_line_ActivePower))
        
            print("\n   Maximum reactive power flow from substation, kVAR: "*string(PMD_MaximumPowerOnsubstation_line_ReactivePower))
            print("\n   Minimum reactive power flow from substation, kVAR: "*string(PMD_MinimumPowerOnsubstation_line_ReactivePower))
            print("\n   Average reactive power flow from substation, kVAR: "*string(PMD_AveragePowerOnsubstation_line_ReactivePower))

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
    return system_results    
end


function combine_PMD_and_simple_powerflow_results(Multinode_Inputs, m, data_eng, PMD_Dictionary_LineFlow_Power_Series, simple_powerflow_model_results)
    # This function combines the powerflow results from the PMD model and the simple powerflow model

    simplified_powerflow_model_timesteps, REoptTimeSteps, time_steps_without_PMD, time_steps_with_PMD = determine_timestep_information(Multinode_Inputs, m, data_eng)
    
    lines = collect(keys(data_eng["line"]))
    
    all_line_powerflows = Dict([])
    
    for line in lines

        ActivePowerFlow_line_temp = []
        ReactivePowerFlow_line_temp = []

        ActivePowerFlow_line_Phase1_temp = []
        ActivePowerFlow_line_Phase2_temp = []
        ActivePowerFlow_line_Phase3_temp = []
        ReactivePowerFlow_line_Phase1_temp = []
        ReactivePowerFlow_line_Phase2_temp = []
        ReactivePowerFlow_line_Phase3_temp = []
        power_flow_model_at_timesteps = []

        for timestep in collect(1:Int(Multinode_Inputs.time_steps_per_hour * 8760))

            if timestep in time_steps_with_PMD
                
                timestep_in_PMD_model = findall(x->x== timestep, time_steps_with_PMD)[1]

                push!(ActivePowerFlow_line_temp, PMD_Dictionary_LineFlow_Power_Series[line]["ActiveLineFlow"][timestep_in_PMD_model])
                push!(ReactivePowerFlow_line_temp, PMD_Dictionary_LineFlow_Power_Series[line]["ReactiveLineFlow"][timestep_in_PMD_model])
                
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase1_ActiveLineFlow"]) > 0)  ?  push!(ActivePowerFlow_line_Phase1_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase1_ActiveLineFlow"][timestep_in_PMD_model]) : push!(ActivePowerFlow_line_Phase1_temp,"N/A")
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase2_ActiveLineFlow"]) > 0)  ?  push!(ActivePowerFlow_line_Phase2_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase2_ActiveLineFlow"][timestep_in_PMD_model]) : push!(ActivePowerFlow_line_Phase2_temp,"N/A")
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase3_ActiveLineFlow"]) > 0)  ?  push!(ActivePowerFlow_line_Phase3_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase3_ActiveLineFlow"][timestep_in_PMD_model]) : push!(ActivePowerFlow_line_Phase3_temp,"N/A")
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase1_ReactiveLineFlow"]) > 0)  ?  push!(ReactivePowerFlow_line_Phase1_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase1_ReactiveLineFlow"][timestep_in_PMD_model]) : push!(ReactivePowerFlow_line_Phase1_temp,"N/A")
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase2_ReactiveLineFlow"]) > 0)  ?  push!(ReactivePowerFlow_line_Phase2_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase2_ReactiveLineFlow"][timestep_in_PMD_model]) : push!(ReactivePowerFlow_line_Phase2_temp,"N/A")
                (length(PMD_Dictionary_LineFlow_Power_Series[line]["Phase3_ReactiveLineFlow"]) > 0)  ?  push!(ReactivePowerFlow_line_Phase3_temp, PMD_Dictionary_LineFlow_Power_Series[line]["Phase3_ReactiveLineFlow"][timestep_in_PMD_model]) : push!(ReactivePowerFlow_line_Phase3_temp,"N/A")

                push!(power_flow_model_at_timesteps, "PMD")

            elseif (timestep in time_steps_without_PMD) && (Multinode_Inputs.apply_simple_powerflow_model_to_timesteps_that_do_not_use_PMD)   
                timestep_in_simple_powerflow_model = findall(x->x== timestep, time_steps_without_PMD)[1]
                push!(ActivePowerFlow_line_temp, simple_powerflow_model_results["lines"][line]["line_power_flow_series"][timestep_in_simple_powerflow_model])
                push!(ReactivePowerFlow_line_temp, "No reactive power in the simple powerflow model")
                
                push!(ActivePowerFlow_line_Phase1_temp, "No phases in the simple powerflow model")
                push!(ActivePowerFlow_line_Phase2_temp, "No phases in the simple powerflow model")
                push!(ActivePowerFlow_line_Phase3_temp, "No phases in the simple powerflow model")
                push!(ReactivePowerFlow_line_Phase1_temp, "No phases in the simple powerflow model")
                push!(ReactivePowerFlow_line_Phase2_temp, "No phases in the simple powerflow model")
                push!(ReactivePowerFlow_line_Phase3_temp, "No phases in the simple powerflow model")

                push!(power_flow_model_at_timesteps, "simplified_powerflow_model")
            else
                push!(ActivePowerFlow_line_temp, "No powerflow model at this time step")
                push!(ReactivePowerFlow_line_temp, "No powerflow model at this time step")
                
                push!(ActivePowerFlow_line_Phase1_temp, "No powerflow model at this time step")
                push!(ActivePowerFlow_line_Phase2_temp, "No powerflow model at this time step")
                push!(ActivePowerFlow_line_Phase3_temp, "No powerflow model at this time step")
                push!(ReactivePowerFlow_line_Phase1_temp, "No powerflow model at this time step")
                push!(ReactivePowerFlow_line_Phase2_temp, "No powerflow model at this time step")
                push!(ReactivePowerFlow_line_Phase3_temp, "No powerflow model at this time step")

                push!(power_flow_model_at_timesteps, "no powerflow model")
            end
        end

        if Int(length(ActivePowerFlow_line_temp)) != Int(Multinode_Inputs.time_steps_per_hour * 8760)
            throw(@error("Error in processing the powerflow results"))
        end

        all_line_powerflows_temp = Dict([(line, Dict([
                                                        ("ActiveLineFlow", ActivePowerFlow_line_temp),
                                                        ("ReactiveLineFlow", ReactivePowerFlow_line_temp),
                                                        ("Phase1_ActiveLineFlow", ActivePowerFlow_line_Phase1_temp),
                                                        ("Phase2_ActiveLineFlow", ActivePowerFlow_line_Phase2_temp),
                                                        ("Phase3_ActiveLineFlow", ActivePowerFlow_line_Phase3_temp),
                                                        ("Phase1_ReactiveLineFlow", ReactivePowerFlow_line_Phase1_temp),
                                                        ("Phase2_ReactiveLineFlow", ReactivePowerFlow_line_Phase2_temp),
                                                        ("Phase3_ReactiveLineFlow", ReactivePowerFlow_line_Phase3_temp),
                                                        ("power_flow_model_at_timesteps", power_flow_model_at_timesteps)
                                                    ]))
                                                    ])

    merge!(all_line_powerflows, all_line_powerflows_temp)

    end

    return all_line_powerflows
end


function determine_timestep_information(Multinode_Inputs, m, data_eng)
    
    if Multinode_Inputs.apply_simple_powerflow_model_to_timesteps_that_do_not_use_PMD
        simplified_powerflow_model_timesteps = collect(1:length(value.(m[:dvPline][collect(keys(data_eng["line"]))[1],:].data))) # pull the total number of timesteps from the first line in the simplified powerflow model
    else
        simplified_powerflow_model_timesteps = "the simplified powerflow model was not used"
    end

    REoptTimeSteps = collect(1:Int(8760* Multinode_Inputs.time_steps_per_hour))
    time_steps_without_PMD = setdiff(REoptTimeSteps, Multinode_Inputs.PMD_time_steps)
    time_steps_with_PMD = Multinode_Inputs.PMD_time_steps

    return simplified_powerflow_model_timesteps, REoptTimeSteps, time_steps_without_PMD, time_steps_with_PMD
end


function process_simple_powerflow_results(Multinode_Inputs, m, data_eng, connections, connections_upstream, connections_downstream)
   # Process the results from the simple powerflow model, which is applied to the time steps that the PMD model isn't applied to

    simplified_powerflow_model_timesteps, REoptTimeSteps, time_steps_without_PMD, time_steps_with_PMD = determine_timestep_information(Multinode_Inputs, m, data_eng)

    if length(time_steps_without_PMD) != length(simplified_powerflow_model_timesteps)
        throw(@error("The lengths of the time step arrays should be the same. This indicates that there is an issue with how the simple powerflow model and/or PMD model was formulated."))
    end

    simple_powerflow_line_results = Dict()
    lines = collect(keys(data_eng["line"]))   
    for line in lines
        simple_powerflow_line_results[line] = Dict("line_power_flow_series" => value.(m[:dvPline][line,:].data),
                                                   "line_maximum_power_flow" => maximum(value.(m[:dvPline][line,:].data)),
                                                   "line_average_power_flow" => mean(value.(m[:dvPline][line,:].data)),
                                                   "line_minimum_power_flow" => minimum(value.(m[:dvPline][line,:].data)),
                                                   "associated_REopt_timesteps" => time_steps_without_PMD,
                                                   "simplified_powerflow_model_timesteps" => simplified_powerflow_model_timesteps

                                                    )
    end

    simple_powerflow_bus_results = Dict()
    busses = axes(m[:dvP][:,1])[1]   
    for bus in busses
        simple_powerflow_bus_results[bus] = Dict("bus_power_series" => value.(m[:dvP][bus,:].data),
                                                   "bus_maximum_power" => maximum(value.(m[:dvP][bus,:].data)),
                                                   "bus_average_power" => mean(value.(m[:dvP][bus,:].data)),
                                                   "bus_minimum_power" => minimum(value.(m[:dvP][bus,:].data)),
                                                   "associated_REopt_timesteps" => time_steps_without_PMD,
                                                   "simplified_powerflow_model_timesteps" => simplified_powerflow_model_timesteps
                                                    )
    end

    simple_powerflow_results = Dict("lines" => simple_powerflow_line_results,
                                    "busses" => simple_powerflow_bus_results,
                                    "all_bus_line_connections" => connections,
                                    "downstream_bus_line_connections" => connections_downstream,
                                    "upstream_bus_line_connections" => connections_upstream)

    # For the original test model: At time step 12, all of these values are the same, as expected:
        #LineFlowOnline4_5 = value.(m[:dvPline]["line4_5",12])
        #ExportFromNode5_SolarPV = value.(m[:dvP][5,12])
        #PowerDemandNode4 = results["REopt_results"][4]["ElectricLoad"]["load_series_kw"][12]
                                        
    return simple_powerflow_results
end


function process_model_diagnostics_bus_voltage_violations(Multinode_Inputs, pm)
    model = pm.model

    bus_voltage_violation_results = Dict()

    BusInfo = create_bus_info_dictionary(pm)
    bus_names = collect(keys(BusInfo))
    PMD_time_steps = collect(1:length(Multinode_Inputs.PMD_time_steps))
    
    #PMDTimeSteps_InREoptTimes = Multinode_Inputs.PMD_time_steps
    #PMDTimeSteps_InPMDTimes = []
    #PMDTimes_toREoptTimes = Dict([])
    #for timestep in REopt_timesteps_for_dashboard_InREoptTimes
    #    PMD_time_step_IndecesForDashboard = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer
    #    push!(PMDTimeSteps_for_dashboard_InPMDTimes, PMD_time_step_IndecesForDashboard)
    #    PMD_dashboard_InPMDTimes_toREoptTimes[PMD_time_step_IndecesForDashboard] = timestep
    #end

    for bus_name in bus_names
        for PMD_time_step in PMD_time_steps
            bin_value = value.(model[Symbol("binBusVoltageViolation")][bus_name, PMD_time_step])
            if bin_value == 1 
                REoptTimeStep = Multinode_Inputs.PMD_time_steps[PMD_time_step]
                
                if string("node_"*bus_name) in keys(bus_voltage_violation_results)
                    entry_to_add_temp = Dict(REoptTimeStep => Dict("associated_PMD_time_step" => PMD_time_step, "per_unit_voltage" => "To add")) # Note: Multinode_Inputs.PMD_time_steps[PMD_time_step] converts the timestep from the PMD timestep (expressed in PMD timesteps) to the PMD timestep (expressed in REopt timesteps)
                    bus_voltage_violation_results[string("node_"*bus_name)] = merge!(bus_voltage_violation_results[string("node_"*bus_name)], entry_to_add_temp)
                else
                    bus_voltage_violation_results[string("node_"*bus_name)] = Dict(REoptTimeStep => Dict("associated_PMD_time_step" => PMD_time_step, "per_unit_voltage" => "To add"))
                end

                if "REopt_timesteps_with_bus_voltage_violations" in keys(bus_voltage_violation_results)
                    if REoptTimeStep in bus_voltage_violation_results["REopt_timesteps_with_bus_voltage_violations"]
                        # Do nothing because the time step is already listed in the array
                    else
                        push!(bus_voltage_violation_results["REopt_timesteps_with_bus_voltage_violations"], REoptTimeStep) 
                    end
                else
                    bus_voltage_violation_results["REopt_timesteps_with_bus_voltage_violations"] = [REoptTimeStep] 
                end

            end
        end
    end

    return bus_voltage_violation_results
end


function VoltageResultsSummary(results)

    DataFrame_BusVoltages = DataFrame(fill(Any[],4), [:Bus, :minimum_pu_voltage, :Average_pu_voltage, :maximum_pu_voltage ])
    per_unit_voltages = Dict([])
    bus_voltage_minimums = []
    bus_voltage_averages = []
    bus_voltage_maximums = []
    for bus in keys(results["nw"]["1"]["bus"]) # read all of the line names from the first time step
        Data_BusVoltages = zeros(3)
        per_unit_voltages[bus] = []
        for timestep in collect(keys(results["nw"]))
            if "w" in keys(results["nw"][string(timestep)]["bus"][bus])
                per_unit_voltages[bus] = push!(per_unit_voltages[bus], sqrt(results["nw"][string(timestep)]["bus"][bus]["w"][1]))
            elseif "Wr" in keys(results["nw"][string(timestep)]["bus"][bus])
                per_unit_voltages[bus] = push!(per_unit_voltages[bus], sqrt(results["nw"][string(timestep)]["bus"][bus]["Wr"][1][1])) # TODO: figure out what "Wi" is in the results when using the SOCNLPUBFPowerModel model
            else
                throw(@error("Bus voltage results data is not available"))            
            end
        end

        Data_BusVoltages[1] = round(minimum(per_unit_voltages[bus][:]), digits = 6)
        Data_BusVoltages[2] = round(mean(per_unit_voltages[bus][:]), digits = 6)
        Data_BusVoltages[3] = round(maximum(per_unit_voltages[bus][:]), digits = 6)
        
        bus_voltage_minimums = push!(bus_voltage_minimums, Data_BusVoltages[1])
        bus_voltage_averages = push!(bus_voltage_averages, Data_BusVoltages[2])
        bus_voltage_maximums = push!(bus_voltage_maximums, Data_BusVoltages[3])

        DataFrame_BusVoltages_temp = DataFrame([("Bus "*string(bus)) Data_BusVoltages[1] Data_BusVoltages[2] Data_BusVoltages[3] ], [:Bus, :minimum_pu_voltage, :Average_pu_voltage, :maximum_pu_voltage])
        DataFrame_BusVoltages = append!(DataFrame_BusVoltages, DataFrame_BusVoltages_temp)
    end

    minimum_voltage = round(minimum(bus_voltage_minimums), digits=6)
    average_voltage = round(mean(bus_voltage_averages), digits=6)
    maximum_voltage = round(maximum(bus_voltage_maximums), digits=6)

    return DataFrame_BusVoltages, per_unit_voltages, minimum_voltage, average_voltage, maximum_voltage
end


function CollectMapInformation(results, Multinode_Inputs)

    if Multinode_Inputs.model_type == "PowerModelsDistribution"
        lines = keys(results["Line_Info_PMD"])
    end

    # Extract the latitude and longitude for the busses
    bus_coordinates_filename = Multinode_Inputs.bus_coordinates
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
    substation_cords = "N/A"
    line_cords = Dict([])
    for i in keys(bus_cords)
        for x in keys(bus_cords)
            if i != x
                if ("line"*i*"_"*x in lines) && (i == Multinode_Inputs.substation_node || x == Multinode_Inputs.substation_node)
                    line_cords["line"*i*"_"*x] = [bus_cords[i],bus_cords[x]]
                    if i == Multinode_Inputs.substation_node
                        substation_cords = bus_cords[i]
                    elseif x == Multinode_Inputs.substation_node
                        substation_cords = bus_cords[x]
                    end
                elseif "line"*i*"_"*x in lines
                    line_cords["line"*i*"_"*x] = [bus_cords[i],bus_cords[x]]
                end
            end
        end
    end
    
    bus_key_values = collect(keys(bus_cords))
    line_key_values = collect(keys(line_cords))

return bus_key_values, line_key_values, bus_cords, line_cords, busses, substation_cords

end

function CollectResultsByNode(results, busses)

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

    return results_by_node
end

function CreateResultsMap(results, Multinode_Inputs, TimeStamp)

    bus_key_values, line_key_values, bus_cords, line_cords, busses = CollectMapInformation(results, Multinode_Inputs) 

    results_by_node = CollectResultsByNode(results, busses)

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
    layout = PlotlyJS.Layout(; title="Multinode Results and Layout", geo=geo,  showlegend = false)
    
    p = PlotlyJS.plot(traces,layout)
    PlotlyJS.savefig(p, Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/Results_and_Layout.html")

    if Multinode_Inputs.display_results
        display(p)
    end
end


function Create_Voltage_Plot(results, TimeStamp, voltage_plot_time_step; file_suffix="")
    Multinode_Inputs = results["Multinode_Inputs"]
    # Generate list of lengths from the node to the substation
    DistancesToSourcebus, lengths_dict, paths_dict, paths, neighbors = DetermineDistanceFromSourcebus(Multinode_Inputs, results["PMD_data_eng"])

    # Determine the per unit voltage at each node
    timestep = voltage_plot_time_step
    
    per_unit_voltage = Dict([])
    for bus in keys(DistancesToSourcebus)
        if "w" in keys(results["PMD_results"]["nw"][string(timestep)]["bus"][bus])
            per_unit_voltage[bus] = sqrt(results["PMD_results"]["nw"][string(timestep)]["bus"][bus]["w"][1])
        elseif "Wr" in keys(results["PMD_results"]["nw"][string(timestep)]["bus"][bus])
            per_unit_voltage[bus] = sqrt(results["PMD_results"]["nw"][string(timestep)]["bus"][bus]["Wr"][1][1]) # TODO: figure out what "Wi" is in the results when using the SOCNLPUBFPowerModel formulation
        else
            throw(@error("Bus voltage results data is not available"))
        end
     end

    # Interactive plot using PlotlyJS
    traces = PlotlyJS.GenericTrace[]
    layout = PlotlyJS.Layout(title_text = "Voltage Stability, PMD Timestep $(timestep)", xaxis_title_text = "Distance from Substation", yaxis_title_text = "Per Unit Voltage")
    
    for line in keys(results["PMD_data_eng"]["line"])
        bus1 = results["PMD_data_eng"]["line"][line]["f_bus"]
        bus2 = results["PMD_data_eng"]["line"][line]["t_bus"]
        push!(traces, PlotlyJS.scatter(name = "Line $(line)", showlegend = false, fill = "none", line = PlotlyJS.attr(width = 1, color="black"),
                x = [DistancesToSourcebus[string(bus1)], DistancesToSourcebus[string(bus2)]],
                y = [per_unit_voltage[string(bus1)], per_unit_voltage[string(bus2)]]
            ))
    end

    for bus in keys(DistancesToSourcebus)
        voltage = round(per_unit_voltage[bus], digits = 6)
        push!(traces, PlotlyJS.scatter(name = "Node $(bus)", showlegend = false, text ="Node $(bus), p.u. voltage $(voltage)", hoverinfo = "text", fill = "none", line = PlotlyJS.attr(width = 3, color="black"),
                x = [DistancesToSourcebus[bus]],
                y = [per_unit_voltage[bus]]
            ))
    end       

    p = PlotlyJS.plot(traces, layout)
    PlotlyJS.savefig(p, Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/VoltagePlot_InteractivePlot"*file_suffix*".html")
    if Multinode_Inputs.display_results
        display(p)
    end
end


function Aggregated_PowerFlows_Plot(results, TimeStamp, Multinode_Inputs, REoptInputs_Combined, model)
    # Function to create additional plots using PlotlyJS
    
    OutageStartTimeStep = Multinode_Inputs.single_outage_start_time_step
    OutageStopTimeStep = Multinode_Inputs.single_outage_end_time_step

    NodeList = []
    for i in Multinode_Inputs.REopt_inputs_list
        push!(NodeList, i["Site"]["node"])
    end

    TotalLoad_series = zeros(Multinode_Inputs.time_steps_per_hour * 8760) # initiate the total load as 0
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
    
    if Multinode_Inputs.display_information_during_modeling_run
        print("\n The nodes with PV are: ")
        print(NodesWithPV)
    end

    # TODO: account for the situation where one node might be exporting PV and then another node might use that power to charge a battery
    PVOutput = zeros(Multinode_Inputs.time_steps_per_hour * 8760)
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
    BatteryOutput = zeros(Multinode_Inputs.time_steps_per_hour * 8760)
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
    GeneratorOutput = zeros(Multinode_Inputs.time_steps_per_hour * 8760)
    for NodeNumberTemp in NodesWithGenerator
        GeneratorOutput = GeneratorOutput + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_load_series_kw"].data + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_grid_series_kw"].data  # + results["REopt_results"][NodeNumberTemp]["Generator"]["electric_to_storage_series_kw"].data 
    end
    
    # Save the REopt Inputs for the site not to a variable
    FacilityMeterNode_REoptInputs = ""
    for p in REoptInputs_Combined
        if string(p.s.site.node) == p.s.settings.facilitymeter_node
            FacilityMeterNode_REoptInputs = p        
        end
    end
    
    # Save power input from the grid to a variable for plotting
    PowerFromGrid = zeros(Multinode_Inputs.time_steps_per_hour * 8760)
    if Multinode_Inputs.model_type == "PowerModelsDistribution"    
        PowerFromGrid = value.(model[Symbol("dvSubstationPowerFlow")]).data  
    end 
       
    #Plot the network-wide power use in a static plot
    days = collect(1:(Multinode_Inputs.time_steps_per_hour * 8760))/(Multinode_Inputs.time_steps_per_hour * 24)
    Plots.plot(days, TotalLoad_series, label="Total Load")
    Plots.plot!(days, PVOutput, label="Combined PV Output")
    Plots.plot!(days, BatteryOutput, label = "Combined Battery Output")
    Plots.plot!(days, GeneratorOutput, label = "Combined Generator Output")
    Plots.plot!(days, PowerFromGrid, label = "Grid Power")
    if Multinode_Inputs.model_outages_with_outages_vector
        if Multinode_Inputs.outages_vector != []
            # TODO: model the multiple outages in the static plot
        end
    elseif (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/24
        OutageStop_Line = OutageStopTimeStep/24
        Plots.plot!([OutageStart_Line, OutageStart_Line],[0,maximum(TotalLoad_series)], label= "Outage Start")
        Plots.plot!([OutageStop_Line, OutageStop_Line],[0,maximum(TotalLoad_series)], label= "Outage End")
        Plots.xlims!(OutageStartTimeStep-12, OutageStopTimeStep+12)
    else
        Plots.xlims!(0,7*Multinode_Inputs.time_steps_per_hour) # Show the first week of results
    end

    if Multinode_Inputs.display_results
        display(Plots.title!("System Wide Power Demand and Generation"))
    end

    # Interactive plot using PlotlyJS
    traces = PlotlyJS.GenericTrace[]
    layout = PlotlyJS.Layout(title_text = "System Wide Power Demand and Generation", xaxis_title_text = "Day", yaxis_title_text = "Power (kW)")
    
    if Multinode_Inputs.model_type == "PowerModelsDistribution"
        
        max = 1.1 * maximum([maximum(TotalLoad_series), maximum(PVOutput), maximum(BatteryOutput), maximum(GeneratorOutput), maximum(PowerFromGrid)])
        min = 1.1 * minimum([minimum(TotalLoad_series), minimum(PVOutput), minimum(BatteryOutput), minimum(GeneratorOutput), minimum(PowerFromGrid)])

        start_values = []
        end_values = []
    
        PMD_TimeSteps_inREoptTime =  Multinode_Inputs.PMD_time_steps

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
            start_temp = start_values[i] / (24* Multinode_Inputs.time_steps_per_hour)
            end_temp = end_values[i] / (24* Multinode_Inputs.time_steps_per_hour)
            
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
    
    if Multinode_Inputs.model_outages_with_outages_vector
        if Multinode_Inputs.outages_vector != []
            
            outage_starts, outage_ends = DetermineOutageStartsAndEnds(Multinode_Inputs, Multinode_Inputs.outages_vector)
            
            for i in outage_starts
                if i == outage_starts[1]
                    showlegend = true
                else
                    showlegend = false
                end
                push!(traces, PlotlyJS.scatter(name = "Outage Start", showlegend = showlegend, fill = "none", line = PlotlyJS.attr(width = 3, color="red"),
                    x = [i, i],
                    y = [0,maximum(TotalLoad_series)]
                ))
            end 

            for i in outage_ends
                if i == outage_ends[1]
                    showlegend = true
                else
                    showlegend = false
                end
                push!(traces, PlotlyJS.scatter(name = "Outage End", showlegend = showlegend, fill = "none", line = PlotlyJS.attr(width = 3, color="red", dash="dot"),
                    x = [i, i],
                    y = [0,maximum(TotalLoad_series)]
                ))
            end 

        end
    elseif (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/(24 * Multinode_Inputs.time_steps_per_hour)
        OutageStop_Line = OutageStopTimeStep/(24 * Multinode_Inputs.time_steps_per_hour)
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
    PlotlyJS.savefig(p, Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/CombinedResults_PowerOutput_InteractivePlot.html")
    if Multinode_Inputs.display_results
        display(p)
    end
end
 

function PlotPowerFlows(results, TimeStamp, REopt_timesteps_for_dashboard_InREoptTimes; file_suffix="")
    # This function plots the power flows through the network

    Multinode_Inputs = results["Multinode_Inputs"]
    bus_key_values, line_key_values, bus_cords, line_cords, busses, substation_cords = CollectMapInformation(results, Multinode_Inputs) 
    results_by_node = CollectResultsByNode(results, busses)

    Multinode_Inputs.display_information_during_modeling_run ? print("\n The substation coordinates are: $(substation_cords)") : nothing

    # Determine the timesteps to plot based on the timesteps the user requested to plot in the dashboard
    maximum_timestep = maximum(REopt_timesteps_for_dashboard_InREoptTimes)
    minimum_timestep = minimum(REopt_timesteps_for_dashboard_InREoptTimes)
    PMDTimeSteps_InREoptTimes = Multinode_Inputs.PMD_time_steps
    timesteps = REopt_timesteps_for_dashboard_InREoptTimes # PMDTimeSteps_for_dashboard_InPMDTimes    
    
    model_total_timesteps = Int(8760*Multinode_Inputs.time_steps_per_hour) 

    #=
    PMDTimeSteps_for_dashboard_InPMDTimes = []
    PMD_dashboard_InPMDTimes_toREoptTimes = Dict([])
    for timestep in REopt_timesteps_for_dashboard_InREoptTimes
        PMD_time_step_IndecesForDashboard = findall(x -> x==timestep, PMDTimeSteps_InREoptTimes)[1] #use the [1] to convert the 1-element vector into an integer
        push!(PMDTimeSteps_for_dashboard_InPMDTimes, PMD_time_step_IndecesForDashboard)
        PMD_dashboard_InPMDTimes_toREoptTimes[PMD_time_step_IndecesForDashboard] = timestep
    end
    =#

    if Multinode_Inputs.model_outages_with_outages_vector 
        PowerOutageIndicator = Array{String}(undef, model_total_timesteps)
        PowerOutageIndicator[:] .= "Not defined"
        for timestep in collect(1:model_total_timesteps) # REopt_timesteps_for_dashboard_InREoptTimes #PMDTimeSteps_for_dashboard_InPMDTimes
            if timestep in Multinode_Inputs.outages_vector
                PowerOutageIndicator[timestep] = " Grid outage"
            else
                PowerOutageIndicator[timestep] = ""
            end
        end
    elseif (Multinode_Inputs.single_outage_end_time_step - Multinode_Inputs.single_outage_start_time_step) > 0
        PowerOutageIndicator = Array{String}(undef, model_total_timesteps)
        PowerOutageIndicator[:] .= "Not defined"
        for timestep in collect(1:model_total_timesteps) # REopt_timesteps_for_dashboard_InREoptTimes # PMDTimeSteps_for_dashboard_InPMDTimes
            if (timestep >= Multinode_Inputs.single_outage_start_time_step) && (timestep <= Multinode_Inputs.single_outage_end_time_step)
                PowerOutageIndicator[timestep] = " Grid outage"
            else
                PowerOutageIndicator[timestep] = ""
            end
        end
    else
        PowerOutageIndicator = repeat([""], model_total_timesteps)
    end
    
    PowerFlowModelIndicator = Array{String}(undef, model_total_timesteps)
    PowerFlowModelIndicator[:] .= "Not defined"
    if Multinode_Inputs.apply_simple_powerflow_model_to_timesteps_that_do_not_use_PMD
        for timestep in collect(1:model_total_timesteps) # timesteps
            if timestep in PMDTimeSteps_InREoptTimes
                PowerFlowModelIndicator[timestep] = "Model: PMD"
            else
                PowerFlowModelIndicator[timestep] = "Model: Simple Powerflow"
            end
        end
    else
        PowerFlowModelIndicator[:] .= "Model: PMD"
    end

    if Multinode_Inputs.display_information_during_modeling_run
        print("\n Timesteps for dashboard (in REopt times) are: ")
        print(timesteps)
    end

    # *******
    # The method in these asterisks came from ChatGPT
    color1 = [30,62,250] # blue
    color2 = [0,255,255] # cyan
    color3 = [255,255,0] # yellow
    color4 = [238,155,0] # orange
    color5 = [215,20,20] # red
    increments = 20 # steps must be a even number
    color1_to_color2 = [color1 .+ (color2 .- color1) * i / ((increments/4)-1) for i in 0:(Int(increments/4)-1) ]
    color2_to_color3 = [color2 .+ (color3 .- color2) * i / ((increments/4)-1) for i in 0:(Int(increments/4)-1) ]
    color3_to_color4 = [color3 .+ (color4 .- color3) * i / ((increments/4)-1) for i in 0:(Int(increments/4)-1) ]
    color4_to_color5 = [color4 .+ (color5 .- color4) * i / ((increments/4)-1) for i in 0:(Int(increments/4)-1) ]
    
    color_numbers = vcat(color1_to_color2, color2_to_color3, color3_to_color4, color4_to_color5)
    
    Colors = [string("rgb(",Int(round(c[1])),",",Int(round(c[2])),",",Int(round(c[3])),")") for c in color_numbers]
    #*******
    
    deleteat!(Colors, increments) # with 20 increments, there should only be 19 color bins

    # Determine the maximum power in the data that is being plotted:
    powerflow = results["Dictionary_LineFlow_Power_Series"]
    max_power = 0
    power = 0
    for key in collect(keys(results["Dictionary_LineFlow_Power_Series"]))
        for i in timesteps
            p = results["Dictionary_LineFlow_Power_Series"][key]["ActiveLineFlow"][i]
            if typeof(p) != String
                power = abs(p)
                if power > max_power
                    max_power = power
                end
            end
        end
    end

    if max_power > 50
        Color_bins = round.(collect(range(0,(ceil(max_power/10)*10),increments)))
    elseif max_power < 10
        increments = Int(increments/2)
        Color_bins = round.(collect(range(0,max_power,increments)), digits=2)
    else
        increments = Int(increments/2)
        Color_bins = round.(collect(range(0,ceil(max_power),increments)), digits=2)
    end
    
    line_colors = Dict{Any, Any}()
    for line in line_key_values
        line_colors[line] = Vector{String}(undef, maximum(model_total_timesteps))
        line_colors[line][:] .= "rgb(1,1,1)" # default rgb(1,1,1), which indicates that data is not shown properly for that timestep
        for i in collect(1:model_total_timesteps) 
            for j in 1:(length(Color_bins)-1)
                if typeof(powerflow[line]["ActiveLineFlow"][i]) != String
                    if (abs(powerflow[line]["ActiveLineFlow"][i]) >= Color_bins[j]) && (abs(powerflow[line]["ActiveLineFlow"][i]) <= Color_bins[j+1])
                        line_colors[line][i] = Colors[j]
                    end
                end
            end
        end
    end
    
    x_bus_values = zeros(length(keys(bus_cords)))
    y_bus_values = zeros(length(keys(bus_cords)))

    for i in collect(1:length(keys(bus_cords)))
        x_bus_values[i] = bus_cords[collect(keys(bus_cords))[i]][2]
        y_bus_values[i] = bus_cords[collect(keys(bus_cords))[i]][1]
    end

    minx = minimum(x_bus_values)
    maxx = maximum(x_bus_values)
    miny = minimum(y_bus_values)
    maxy = maximum(y_bus_values)
    y0 = zeros(increments)
    y1 = zeros(increments)
    stepsize = (maxy - miny)/increments
    x_spacing = 0.05*(maxx - minx)
    legend_box_width = 0.02*(maxx - minx)
    x0 = maxx + x_spacing
    x1 = maxx + x_spacing + legend_box_width
    scaleratio_input = 0.85 # TODO: determine if this scale ratio should be different for different latitudes

    for i in collect(1:increments)
        y0[i] = miny + ((i-1)*stepsize)
        y1[i] = miny + (i * stepsize)
    end

    start_day = minimum_timestep/(24*Multinode_Inputs.time_steps_per_hour)
    end_day = maximum_timestep/(24*Multinode_Inputs.time_steps_per_hour)
    Symbol_data_inputs = SymbolData(results, line_cords, REopt_timesteps_for_dashboard_InREoptTimes, minx, maxx, scaleratio_input)

    start_datetime = Dates.format(DateTime(2021, 1, 1) + Day(floor(start_day)) + Second(round(60*60*24*(start_day - floor(start_day)))), "U d at HH:MM") # This line of code is based off of code suggested by generative AI
    end_datetime = Dates.format(DateTime(2021, 1, 1) + Day(floor(end_day)) + Second(round(60*60*24*(end_day - floor(end_day)))), "U d at HH:MM") # This line of code is based off of code suggested by generative AI

    frames = PlotlyJS.PlotlyFrame[ PlotlyJS.frame(             
            data = [PlotlyJS.scatter(x=[line_cords[line_key_values[i]][1][2], line_cords[line_key_values[i]][2][2]], y=[line_cords[line_key_values[i]][1][1], line_cords[line_key_values[i]][2][1]], mode="lines+markers",marker=PlotlyJS.attr(color="black"), line=PlotlyJS.attr(width=3, color = line_colors[line_key_values[i]][j])) for i in collect(1:length(line_cords))], 
            name = "time=$(j)",
            layout=PlotlyJS.attr(title_text="Power Flow Time Series Animation, from  $(start_datetime)  to  $(end_datetime)", 
                                 xaxis_title_text = "",
                                 yaxis_title_text = "",
                                 annotations = vcat([PlotlyJS.attr(x=x1,y=y0[i],text=Color_bins[i], xanchor="left", yanchor="center", showarrow=false) for i in collect(1:increments)], 
                                                    [PlotlyJS.attr(x=x1,y=y1[increments],text="Power (kW)", xanchor="center", yanchor="bottom", showarrow=false)],
                                                    [PlotlyJS.attr(x=substation_cords[2], y=substation_cords[1], text=PowerOutageIndicator[j], font = PlotlyJS.attr(color="red", size = 16), xanchor="left", yanchor="bottom", showarrow=false)],
                                                    [PlotlyJS.attr(x=x1, y=y1[increments]+stepsize+stepsize, text=PowerFlowModelIndicator[j], font = PlotlyJS.attr(color="black", size = 16), xanchor="right", yanchor="bottom", showarrow=false)],
                                                    [PlotlyJS.attr(x=bus_cords[bus_key_values[j]][2], y=bus_cords[bus_key_values[j]][1], text=bus_key_values[j]*results_by_node[bus_key_values[j]], xanchor="left", yanchor="bottom", showarrow=false) for j in 1:length(bus_key_values) ]),
             
                                 shapes = vcat([PlotlyJS.line(xref='x', yref='y', 
                                                         x0= Symbol_data_inputs[line_key_values[k]][1][1], 
                                                         y0= Symbol_data_inputs[line_key_values[k]][1][2], 
                                                         x1= Symbol_data_inputs[line_key_values[k]][3][j], 
                                                         y1= Symbol_data_inputs[line_key_values[k]][4][j], 
                                                         line = PlotlyJS.attr(color=line_colors[line_key_values[k]][j]), 
                                                         ) for k in 1:length(line_cords)],
                                                [PlotlyJS.line(xref='x', yref='y', 
                                                         x0= Symbol_data_inputs[line_key_values[k]][1][1], 
                                                         y0= Symbol_data_inputs[line_key_values[k]][1][2], 
                                                         x1= Symbol_data_inputs[line_key_values[k]][5][j], 
                                                         y1= Symbol_data_inputs[line_key_values[k]][6][j], 
                                                         line = PlotlyJS.attr(color=line_colors[line_key_values[k]][j]), 
                                                         ) for k in 1:length(line_cords)],
                                               [PlotlyJS.rect(x0=x0, y0= y0[i], x1=x1, y1=y1[i], fillcolor=Colors[i], line=PlotlyJS.attr(width=0), xref='x',yref='y') for i in collect(1:(increments-1))])
                                )) for j in timesteps]
    
    steps_days = [Dates.format(DateTime(2021, 1, 1) + Day(floor(day)) + Second(round(60*60*24*(day - floor(day)))), "U d at HH:MM") for day in (collect(1:model_total_timesteps)/(24*Multinode_Inputs.time_steps_per_hour))]# This line of code is based off of code suggested by generative AI
    
    steps = [PlotlyJS.attr(method = "animate",
            args = [["time=$(i)"], PlotlyJS.attr(frame=PlotlyJS.attr(duration=500, redraw=true), mode="immediate", transition=PlotlyJS.attr(duration=0))],
            #label = "$(round(i/(24*Multinode_Inputs.time_steps_per_hour), digits=2))") for i in timesteps]
            label = steps_days[i]*" (ts=$(i))") for i in timesteps]
    layout = PlotlyJS.Layout(
        showlegend=false,
        xaxis = PlotlyJS.attr(showticklabels=false, scaleanchor='y', scaleratio = scaleratio_input),
        yaxis = PlotlyJS.attr(showticklabels=false, scaleanchor='x'),
        #annotations = vcat([PlotlyJS.attr(x=x1,y=y0[i],text=Color_bins[i], xanchor="left", yanchor="center", showarrow=false) for i in collect(1:increments)], 
        #                   [PlotlyJS.attr(x=x1,y=y1[increments],text="Power (kW)", xanchor="center", yanchor="bottom", showarrow=false)],
        #                   [PlotlyJS.attr(x=bus_cords[bus_key_values[j]][2], y=bus_cords[bus_key_values[j]][1], text=bus_key_values[j]*results_by_node[bus_key_values[j]], xanchor="left", yanchor="bottom", showarrow=false) for j in 1:length(bus_key_values) ]),
                          
                        
        sliders=[PlotlyJS.attr(yanchor="top", 
                    xanchor="left",
                    currentvalue=PlotlyJS.attr(prefix="Day: ", visible=true, font_size=12),
                    steps=steps,
                    active=0,
                    minorticklen=0
                    )],
        updatemenus = [PlotlyJS.attr(
            type="buttons",
            showactive=false,
            buttons=[
                PlotlyJS.attr(
                    label="Animate", method="animate",
                    args=[nothing,PlotlyJS.attr(transition=PlotlyJS.attr(duration=0),fromcurrent=true, visible=true, frame=PlotlyJS.attr(duration=500, redraw=true), mode="immediate")]),
                PlotlyJS.attr(
                    label="Pause", method="animate",
                    args=[[nothing],PlotlyJS.attr(transition=PlotlyJS.attr(duration=0), mode="immediate")])
        ])])
    
    data = [PlotlyJS.scatter(x=[line_cords[line_key_values[i]][1][2], line_cords[line_key_values[i]][2][2]], y=[line_cords[line_key_values[i]][1][1], line_cords[line_key_values[i]][2][1]], line=PlotlyJS.attr(width=3, color = line_colors[line_key_values[i]][timesteps[1]])) for i in 1:length(line_cords)]
            
    p = PlotlyJS.Plot(data, layout, frames)

    PlotlyJS.savefig(p, Multinode_Inputs.folder_location*"/results_"*TimeStamp*"/PowerFlowAnimation"*file_suffix*".html")
    
    #display(p) # do not display because this plot does not work in VScode
    return frames, layout, steps, line_cords, bus_cords, data,  bus_key_values, line_key_values, line_colors, timesteps, powerflow, Symbol_data_inputs
end


function SymbolData(results, line_cords, timesteps_to_model, minx, maxx, scaleratio_input)
    # Function to generate information for mapping a power flow direction symbol in the power flow chart
    SymbolDictionary = Dict()
    powerflow = results["Dictionary_LineFlow_Power_Series"]
    
    for i in collect(keys(line_cords))
        midpoint = [0,0]
        x_average = 0.5 * (line_cords[i][1][2] + line_cords[i][2][2])
        y_average = 0.5 * (line_cords[i][1][1] + line_cords[i][2][1])
        midpoint = [x_average, y_average]
        
        x_change = line_cords[i][2][2] - line_cords[i][1][2]
        y_change = line_cords[i][2][1] - line_cords[i][1][1]
        if x_change != 0
            slope_radians = atan(y_change, x_change)
        elseif y_change > 0
            slope_radians = 3.14159 / 2
        elseif y_change < 0
            slope_radians = -3.14159 / 2
        end
        slope_degrees = slope_radians * (180 / 3.14159)
        SymbolDictionary[i] = [midpoint, slope_degrees, [], [], [], []] # initiate the arrays for the end points of the arrows
        arrow_angle_radians = pi / 4 
        arrow_length = 0.01 * (maxx - minx) # define the arrow length as a fraction of the plot size
        x2 = zeros(maximum(timesteps_to_model))
        y2 = zeros(maximum(timesteps_to_model))
        x3 = zeros(maximum(timesteps_to_model))
        y3 = zeros(maximum(timesteps_to_model))

        for j in timesteps_to_model
            active_power = powerflow[i]["ActiveLineFlow"][j]

            if active_power < -0.001
                x2[j] = midpoint[1] + (arrow_length * cos(slope_radians + arrow_angle_radians))
                y2[j] = midpoint[2] + (arrow_length * sin(slope_radians + arrow_angle_radians) * scaleratio_input)

                x3[j] = midpoint[1] + (arrow_length * cos(slope_radians - arrow_angle_radians))
                y3[j] = midpoint[2] + (arrow_length * sin(slope_radians - arrow_angle_radians) * scaleratio_input)
            
            elseif active_power > 0.001
                x2[j] = midpoint[1] - (arrow_length * cos(slope_radians + arrow_angle_radians))
                y2[j] = midpoint[2] - (arrow_length * sin(slope_radians + arrow_angle_radians) * scaleratio_input)

                x3[j] = midpoint[1] - (arrow_length * cos(slope_radians - arrow_angle_radians))
                y3[j] = midpoint[2] - (arrow_length * sin(slope_radians - arrow_angle_radians) * scaleratio_input)
            
            else
                # If there is no power flow in the line, draw the angled line to start and stop at the midpoint (so no arrow will be shown)
                x2[j] = midpoint[1]
                y2[j] = midpoint[2]
                x3[j] = midpoint[1]
                y3[j] = midpoint[2]
            end
        end

        SymbolDictionary[i][3] = x2
        SymbolDictionary[i][4] = y2
        SymbolDictionary[i][5] = x3
        SymbolDictionary[i][6] = y3       
    end

    return  SymbolDictionary
end


function DetermineOutageStartsAndEnds(Multinode_Inputs, outages_vector)
    # From the list of outage timesteps, construct an array for the outage start times and outage end times by identifying groups of values

    outage_starts = [outages_vector[1]]
    outage_ends = []

    for i in collect(2:length(outages_vector))
        if (outages_vector[i] - outages_vector[i-1]) >= 2
            push!(outage_starts, outages_vector[i])
            push!(outage_ends, outages_vector[i-1])
        end
    end

    # Make sure that the last value in the outage vector is part of the outage_ends array:
    if outage_ends[length(outage_ends)] != outages_vector[length(outages_vector)]
        push!(outage_ends, outages_vector[length(outages_vector)])
    end
    # Convert to days:
    outage_starts = outage_starts / (24 * Multinode_Inputs.time_steps_per_hour)
    outage_ends = outage_ends / (24 * Multinode_Inputs.time_steps_per_hour)
    return outage_starts, outage_ends
end


function DetermineDistanceFromSourcebus(Multinode_Inputs, data_eng)
    neighbors = REopt.modified_calc_connected_components_eng(data_eng)
    paths = REopt.DeterminePathToSourcebus(neighbors)

    #Multinode_Inputs = results["Multinode_Inputs"]

    line_names_to_sourcebus_dict = Dict()
    lengths_to_sourcebus_dict = Dict()

    for i in keys(paths)
        path = paths[i]
        line_names_temp = []
        line_lengths_temp = []

        for j in collect(1:(length(path)-1))
            firstnode = path[j]
            if path[j] == "sourcebus"
                firstnode = string(Multinode_Inputs.substation_node)
            end
            line_name = string("line"*firstnode*"_"*path[j+1])
            if haskey(data_eng["line"], line_name)
                push!(line_names_temp, line_name)
                push!(line_lengths_temp, data_eng["line"][line_name]["length"])
            end
        end
        line_names_to_sourcebus_dict[i] = line_names_temp
        lengths_to_sourcebus_dict[i] = line_lengths_temp
    end
    
    summed_lengths_to_sourcebus_dict = Dict()
    for i in keys(lengths_to_sourcebus_dict)
        if lengths_to_sourcebus_dict[i] != Any[]
            summed_lengths_to_sourcebus_dict[i] = sum(lengths_to_sourcebus_dict[i])
        else
            summed_lengths_to_sourcebus_dict[i] = 0
        end
    end

    return summed_lengths_to_sourcebus_dict, lengths_to_sourcebus_dict, line_names_to_sourcebus_dict, paths, neighbors
end


function DeterminePathToSourcebus(neighbors)
    # Acknowledgement: This function was built with the assistance of ChatGPT
    parent_dict = Dict()
    path_dict = Dict()
    substation_bus = "sourcebus"
    queue = [substation_bus]
    visited = Dict()
    visited[substation_bus] = true

    while !isempty(queue)
        bus = popfirst!(queue)
        for i in neighbors[bus]
            if !haskey(visited, i)
                visited[i] = true
                parent_dict[i] = bus
                push!(queue, i)
            end
        end
    end

    for bus in keys(neighbors)
        path = []
        current_bus = bus
        while current_bus != substation_bus
            push!(path, current_bus)
            current_bus = parent_dict[current_bus]
        end
        push!(path, substation_bus)
        path_dict[bus] = reverse(path)
    end

    return path_dict
end


function modified_calc_connected_components_eng(data; edges::Vector{<:String}=String["line", "switch", "transformer"], type::Union{Missing,String}=missing, check_enabled::Bool=true) #::Set{Set{String}}
    # Acknowledgement: This function is based on code from the julia package PowerModelsDistribution
    
    @assert get(data, "data_model", MATHEMATICAL) == ENGINEERING

    active_bus = Dict{String,Dict{String,Any}}(x for x in data["bus"] if x.second["status"] == ENABLED || !check_enabled)
    active_bus_ids = Set{String}([i for (i,bus) in active_bus])

    neighbors = Dict{String,Vector{String}}(i => [] for i in active_bus_ids)
    for edge_type in edges
        for (id, edge_obj) in get(data, edge_type, Dict{Any,Dict{String,Any}}())
            if edge_obj["status"] == ENABLED || !check_enabled
                if edge_type == "transformer" && haskey(edge_obj, "bus")
                    for f_bus in edge_obj["bus"]
                        for t_bus in edge_obj["bus"]
                            if f_bus != t_bus
                                push!(neighbors[f_bus], t_bus)
                                push!(neighbors[t_bus], f_bus)
                            end
                        end
                    end
                else
                    if edge_type == "switch" && !ismissing(type)
                        if type == "load_blocks"
                            if edge_obj["dispatchable"] == NO && edge_obj["state"] == CLOSED
                                push!(neighbors[edge_obj["f_bus"]], edge_obj["t_bus"])
                                push!(neighbors[edge_obj["t_bus"]], edge_obj["f_bus"])
                            end
                        elseif type == "blocks"
                            if edge_obj["state"] == CLOSED
                                push!(neighbors[edge_obj["f_bus"]], edge_obj["t_bus"])
                                push!(neighbors[edge_obj["t_bus"]], edge_obj["f_bus"])
                            end
                        end
                    else
                        push!(neighbors[edge_obj["f_bus"]], edge_obj["t_bus"])
                        push!(neighbors[edge_obj["t_bus"]], edge_obj["f_bus"])
                    end
                end
            end
        end
    end

    component_lookup = Dict(i => Set{String}([i]) for i in active_bus_ids)
    touched = Set{String}()

    for i in active_bus_ids
        if !(i in touched)
            PowerModelsDistribution._cc_dfs(i, neighbors, component_lookup, touched)
        end
    end
    return neighbors 
end


function Check_REopt_PMD_Alignment(m, PMD_results, node, line, phase)
    # Compare the REopt and PMD results to ensure the models are linked
        # Note the calculations below are only valid if there are not any REopt nodes or PMD loads downstream of the node being evaluated
    
    Node = node # This is for the REopt data
    Line = line # This is for the PMD data
    Phase = phase # This data is for the PMD data

    # Save REopt data to variables for comparison with PMD:
    TotalExport = JuMP.value.(m[Symbol("TotalExport_"*string(Node))]) #[1]
    TotalImport = JuMP.value.(m[Symbol("dvGridPurchase_"*string(Node))]) #[1] If needed, define the time step in the brackets appended to this line
    REopt_power_injection = TotalImport - TotalExport

    # Save the power injection data from PMD into a vector for the line
    PowerFlow_line = []
    for i in 1:length(PMD_results["nw"])
        push!(PowerFlow_line, PMD_results["nw"][string(i)]["line"][Line]["pf"][Phase]) # for other PMD formulations, the "pf" might be "Pf" instead
    end

    # This calculation compares the power flow through the Line (From PMD), to the power injection into the Node (From REopt). If the PMD and REopt models are connected, this should be zero or very close to zero.
    Mismatch_in_expected_powerflow = PowerFlow_line - REopt_power_injection[1:length(PMD_results["nw"])].data   # This is only valid for the model with only one REopt load on node 1

    # Visualize the mismatch to ensure the results are zero for each time step
    Plots.plot(collect(1:length(PMD_results["nw"])), Mismatch_in_expected_powerflow)
    Plots.xlabel!("Timestep")
    Plots.ylabel!("Mismatch between REopt and PMD (kW)")
    display(Plots.title!("REopt and PMD Mismatch: Node $(Node), Phase $(Phase)"))
end 

