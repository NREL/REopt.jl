# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

const PMD = PowerModelsDistribution

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


function Results_Processing_REopt_PMD_Model(m, results, data_math_mn, REoptInputs_Combined, Microgrid_Inputs, timestamp; allow_upgrades=false, line_upgrade_options_each_line ="")
    # Extract the PMD results
    print("\n Reading the PMD results")
    sol_math = results["solution"]
    # The PMD results are saved to the sol_eng variable
    sol_eng = transform_solution(sol_math, data_math_mn)

    # Extract the REopt results
    print("\n Reading the REopt results")
    REopt_results = reopt_results(m, REoptInputs_Combined)

    if allow_upgrades == true && Microgrid_Inputs.model_line_upgrades == true
        line_upgrades = Process_Line_Upgrades(m, line_upgrade_options_each_line, Microgrid_Inputs, timestamp)
    else
        line_upgrades = "N/A"
    end

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
    
    return REopt_results, sol_eng, DataDictionaryForEachNodeForOutageSimulator, Dictionary_LineFlow_Power_Series, DataFrame_LineFlow, line_upgrades
end


function Process_Line_Upgrades(m, line_upgrade_options_each_line, Microgrid_Inputs, TimeStamp)

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
    if Microgrid_Inputs.generate_CSV_of_outputs
        CSV.write(Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/Results_Line_Upgrade_Summary_"*TimeStamp*".csv", line_upgrade_results)
    end

    return line_upgrade_results
end


function Check_REopt_PMD_Alignment(Microgrid_Inputs, m, PMD_results, node, line, phase)
    # Compare the REopt and PMD results to ensure the models are linked
        # Note the calculations below are only valid if there are not any REopt nodes or PMD loads downstream of the node being evaluated
    
    Node = node #3 # This is for the REopt data
    Line = line # "line2_3" # This is for the PMD data
    Phase = phase # 1  # This data is for the PMD data

    # Save REopt data to variables for comparison with PMD:
    TotalExport = JuMP.value.(m[Symbol("TotalExport_"*string(Node))]) #[1]
    TotalImport = JuMP.value.(m[Symbol("dvGridPurchase_"*string(Node))]) #[1] If needed, define the time step in the brackets appended to this line
    REopt_power_injection = TotalImport - TotalExport

    #GridImport_REopt = REopt_results[Node]["ElectricUtility"]["electric_to_storage_series_kw"] + REopt_results[Node]["ElectricUtility"]["electric_to_load_series_kw"] 
  
    # Save the power injection data from PMD into a vector for the line
    PowerFlow_line = []
    for i in 1:length(PMD_results["nw"])
        push!(PowerFlow_line, PMD_results["nw"][string(i)]["line"][Line]["pf"][Phase])
    end

    # This calculation compares the power flow through the Line (From PMD), to the power injection into the Node (From REopt). If the PMD and REopt models are connected, this should be zero or very close to zero.
    Mismatch_in_expected_powerflow = PowerFlow_line - REopt_power_injection[1:length(PMD_results["nw"])].data   # This is only valid for the model with only one REopt load on node 1

    # Visualize the mismatch to ensure the results are zero for each time step
    Plots.plot(collect(1:length(PMD_results["nw"])), Mismatch_in_expected_powerflow)
    Plots.xlabel!("Timestep")
    Plots.ylabel!("Mismatch between REopt and PMD (kW)")
    display(Plots.title!("REopt and PMD Mismatch: Node $(Node), Phase $(Phase)"))
end 


function Results_Compilation(model, results, Outage_Results, Microgrid_Inputs, DataFrame_LineFlow_Summary, Dictionary_LineFlow_Power_Series, TimeStamp, ComputationTime_EntireModel; bau_model = "", system_results_BAU = "", line_upgrade_results = "", transformer_upgrade_results = "", outage_simulator_time = "")
    
    @info "Compiling the results"

    InputsList = Microgrid_Inputs.REopt_inputs_list

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

    if Microgrid_Inputs.model_line_upgrades
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
            #=
            elseif Microgrid_Inputs.model_type == "BasicLinear"
                LineFromSubstationToFacilityMeter = Microgrid_Inputs.substation_node * "-" * Microgrid_Inputs.facility_meter_node

                MaximumPowerOnsubstation_line_ActivePower = (round(maximum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
                MinimumPowerOnsubstation_line_ActivePower = (round(minimum(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
                AveragePowerOnsubstation_line_ActivePower = (round(mean(Dictionary_LineFlow_Power_Series[LineFromSubstationToFacilityMeter]["NetRealLineFlow"]), digits = 0))
                
                # Temporarily not recording the reactive power through the lines:
                MaximumPowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
                MinimumPowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
                AveragePowerOnsubstation_line_ReactivePower = zeros(Microgrid_Inputs.time_steps_per_hour * 8760)
            =#
            end

            # Add system-level results

            push!(DataLabels, "----Optimization Parameters----")
            push!(Data,"")
            push!(DataLabels, "  Number of Variables")
            push!(Data, length(all_variables(model)))
            push!(DataLabels, "  Computation time, including the BAU model and the outage simulator if used (minutes)")
            push!(Data, round((Dates.value(ComputationTime_EntireModel)/(1000*60)), digits=2))
            push!(DataLabels, "  Model solve time (minutes)" )
            push!(Data, round(JuMP.solve_time(model)/60, digits = 2))
            
            if Microgrid_Inputs.run_BAU_case 
                push!(DataLabels, "  BAU model solve time (minutes)" )
                push!(Data, round(JuMP.solve_time(bau_model)/60, digits = 2))
            end
            if Microgrid_Inputs.run_outage_simulator
                push!(DataLabels, "  Total outage simulation time (minutes)")
                push!(Data, round((Dates.value(outage_simulator_time)/(1000*60)), digits=2))
            end

            push!(DataLabels, "----System Results----")
            push!(Data,"")

            push!(DataLabels,"  Total Lifecycle Cost (LCC)")
            push!(Data, round(system_results["total_lifecycle_cost"], digits=0))
            push!(DataLabels,"  Total Lifecycle Capital Cost (LCCC)")
            push!(Data, round(system_results["total_lifecycle_capital_cost"], digits=0))

            if Microgrid_Inputs.run_BAU_case 
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
    return system_results    
end


function CreateResultsMap(results, Microgrid_Inputs, TimeStamp)

    if Microgrid_Inputs.model_type == "PowerModelsDistribution"
        lines = keys(results["Line_Info_PMD"])
    #=
    elseif Microgrid_Inputs.model_type == "BasicLinear"
        lines = keys(results["FromREopt_Dictionary_LineFlow_Power_Series"])
    =#
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
    #=
    elseif Microgrid_Inputs.model_type == "BasicLinear"
        PowerFromGrid = results["FromREopt_Dictionary_LineFlow_Power_Series"]["0-15"]["NetRealLineFlow"]
    =#
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
    if Microgrid_Inputs.model_outages_with_outages_vector
        if Microgrid_Inputs.outages_vector != []
            # TODO: model the multiple outages in the static plot
        end
    elseif (OutageStopTimeStep - OutageStartTimeStep) > 0
        OutageStart_Line = OutageStartTimeStep/24
        OutageStop_Line = OutageStopTimeStep/24
        Plots.plot!([OutageStart_Line, OutageStart_Line],[0,maximum(TotalLoad_series)], label= "Outage Start")
        Plots.plot!([OutageStop_Line, OutageStop_Line],[0,maximum(TotalLoad_series)], label= "Outage End")
        Plots.xlims!(OutageStartTimeStep-12, OutageStopTimeStep+12)
    else
        Plots.xlims!(0,7*Microgrid_Inputs.time_steps_per_hour) # Show the first week of results
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
    
    if Microgrid_Inputs.model_outages_with_outages_vector
        if Microgrid_Inputs.outages_vector != []
            
            outage_starts, outage_ends = DetermineOutageStartsAndEnds(Microgrid_Inputs, Microgrid_Inputs.outages_vector)
            
            for i in outage_starts
                if i == outage_starts[1]
                    showlegend = true
                else
                    showlegend = false
                end
                push!(traces, PlotlyJS.scatter(name = "Outage Start", showlegend = showlegend, fill = "none", line = PlotlyJS.attr(width = 3, color="red"), #, dash="dot"),
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
    PlotlyJS.savefig(p, Microgrid_Inputs.folder_location*"/results_"*TimeStamp*"/CombinedResults_PowerOutput_InteractivePlot.html")
end
 

function DetermineOutageStartsAndEnds(Microgrid_Inputs, outages_vector)
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
    outage_starts = outage_starts / (24 * Microgrid_Inputs.time_steps_per_hour)
    outage_ends = outage_ends / (24 * Microgrid_Inputs.time_steps_per_hour)
    return outage_starts, outage_ends
end

