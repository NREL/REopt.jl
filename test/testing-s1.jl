using REopt
using JuMP
# using Cbc
using HiGHS
# using Xpress
using JSON
using StatsPlots

using Printf

ENV["NREL_DEVELOPER_API_KEY"]="ogQAO0gClijQdYn7WOKeIS02zTUYLbwYJJczH9St"

function print_results(results)
    println("Sub-system Sizing:")
    if "PV" in keys(results)
        println(@sprintf("\tPV: %5.3f kW", results["PV"]["size_kw"]))  
    else
        println("\tPV not in results.")
    end
    if "ElectricHeater" in keys(results)
        println(@sprintf("\tElectric Heater: %5.3f kW", results["ElectricHeater"]["size_mmbtu_per_hour"] * 293.07107))  # mmbtu/hr -> kW
    else
        println("\tElectric Heater not in results.")
    end
    if "HotSensibleTes" in keys(results)
        println(@sprintf("\tHot Sensible TES: %5.3f m^3", results["HotSensibleTes"]["size_gal"] / 264.1725))    # gal -> m^3
    else
        println("\tHot Sensible TES not in results.")
    end
    if "HotThermalStorage" in keys(results)
        println(@sprintf("\tHot Thermal Storage: %5.3f gal", results["HotThermalStorage"]["size_gal"])) 
    else
        println("\tHot TES not in results.")
    end
    if "SteamTurbine" in keys(results)
        println(@sprintf("\tSteam Turbine: %5.3f kW", results["SteamTurbine"]["size_kw"]))
    else
        println("\tSteam Turbine not in results.")
    end
    if "CST" in keys(results)
        println(@sprintf("\tConcentrating Solar: %5.3f kW", results["CST"]["size_kw"]))
    else
        println("\tConcentrating Solar not in results.")
    end

    println("Summary of Loads:")
    if "ElectricLoad" in keys(results)
        println("\tAnnual electric load: ", results["ElectricLoad"]["annual_calculated_kwh"], " kWh")
    else
        println("\tNo Electric Load.")
    end
    println("\tAnnual process heat load: ", results["HeatingLoad"]["annual_calculated_process_heat_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual space heating load: ", results["HeatingLoad"]["annual_calculated_space_heating_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual hot water load: ", results["HeatingLoad"]["annual_calculated_dhw_thermal_load_mmbtu"], " mmbtu")
    println("\tAnnual total heating load: ", results["HeatingLoad"]["annual_calculated_total_heating_thermal_load_mmbtu"], " mmbtu")

    println("Electric Utility:")
    if "ElectricUtility" in keys(results)
        println("\tAnnual grid purchases: ", results["ElectricUtility"]["annual_energy_supplied_kwh"], " kWh")
        println("\tLifecyle Electrical Bill After Tax: \$", results["Financial"]["lifecycle_elecbill_after_tax"])
    else
        println("\tNo electricity costs in results.")
    end
    println("Generation:")
    if "PV" in keys(results)
        println("\tPV production: ", results["PV"]["annual_energy_produced_kwh"], " kWh")
    end

    if "ExistingBoiler" in keys(results)
        println("Existing Boiler:")
        println("\tBoiler to Turbine: ", round(sum(results["ExistingBoiler"]["thermal_to_steamturbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Load: ", round(sum(results["ExistingBoiler"]["thermal_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Storage: ", round(sum(results["ExistingBoiler"]["thermal_to_storage_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Hot Water: ", round(sum(results["ExistingBoiler"]["thermal_to_dhw_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Space Heating: ", round(sum(results["ExistingBoiler"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tBoiler to Process Heat: ", round(sum(results["ExistingBoiler"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tAnnual production: ", results["ExistingBoiler"]["annual_thermal_production_mmbtu"], " mmbtu")
    else
        println("No Existing Boiler in results.")
    end

    if "ElectricHeater" in keys(results)
        println("ElectricHeater:")
        println("\tElectricHeater Size: ", results["ElectricHeater"]["size_mmbtu_per_hour"], " mmbtu/hr")
        println("\tElectricHeater Electric Consumption: ", round(results["ElectricHeater"]["annual_electric_consumption_kwh"], digits = 2), " kWh")
        println("\tElectricHeater Thermal to Load: ", round(sum(results["ElectricHeater"]["thermal_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Turbine: ", round(sum(results["ElectricHeater"]["thermal_to_steamturbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to All Hot Storage: ", round(sum(results["ElectricHeater"]["thermal_to_storage_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to HotSensibleTes: ", round(sum(results["ElectricHeater"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println(results["ElectricHeater"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"][1:24])
        println("\tElectricHeater Thermal to Hot Water: ", round(sum(results["ElectricHeater"]["thermal_to_dhw_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Space Heating: ", round(sum(results["ElectricHeater"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tElectricHeater Thermal to Process Heat: ", round(sum(results["ElectricHeater"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
    end
    if "HotSensibleTes" in keys(results)
        println("HotSensibleTes:")
        println("\tHotSensibleTes Size: ", results["HotSensibleTes"]["size_gal"], " gal")
        println("\tHotSensibleTes Size: ", results["HotSensibleTes"]["size_kwh"], " kWh")
        println("\tHotSensibleTes to Turbine: ", round(sum(results["HotSensibleTes"]["storage_to_turbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tHotSensibleTes to Load: ", round(sum(results["HotSensibleTes"]["storage_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println(results["HotSensibleTes"]["storage_to_load_series_mmbtu_per_hour"][1:24])
    end
    if "HotThermalStorage" in keys(results)
        println("\tHotThermalStorage Size: ", results["HotThermalStorage"]["size_gal"], " gal")
        println("\tHotThermalStorage Size: ", results["HotThermalStorage"]["size_kwh"], " kWh")
        println("\tHotThermalStorage to Turbine: ", round(sum(results["HotThermalStorage"]["storage_to_turbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tHotThermalStorage to Load: ", round(sum(results["HotThermalStorage"]["thermal_to_storage_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
    end
    if "SteamTurbine" in keys(results)
        println("Steam Turbine:")
        println("\tSteam Turbine Size: ", results["SteamTurbine"]["size_kw"], " kW")
        println("\tAnnual thermal consumption: ", results["SteamTurbine"]["annual_thermal_consumption_mmbtu"], " mmbtu")
        println("\tAnnual electric production: ", results["SteamTurbine"]["annual_electric_production_kwh"], " kWh")
        println("\tAnnual thermal production: ", results["SteamTurbine"]["annual_thermal_production_mmbtu"], " mmbtu")
        println("\tSteam Turbine to All Hot Thermal Storage: ", round(sum(results["SteamTurbine"]["thermal_to_storage_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Hot Sensible TES: ", round(sum(results["SteamTurbine"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Hot Water Load: ", round(sum(results["SteamTurbine"]["thermal_to_dhw_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Space Heating Load: ", round(sum(results["SteamTurbine"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tSteam Turbine to Process Heat Load: ", round(sum(results["SteamTurbine"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
    end

    if "CST" in keys(results)
        println("ConcentratingSolar:")
        println("\tConcentratingSolar Size: ", results["CST"]["size_kw"], " kW")
        # println("\tConcentratingSolar Electric Consumption: ", round(results["CST"]["annual_electric_consumption_kwh"], digits = 2), " kWh")
        println("\tConcentratingSolar Thermal to Load: ", round(sum(results["CST"]["thermal_to_load_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        # println(results["CST"]["thermal_to_load_series_mmbtu_per_hour"][1:24])
        println("\tConcentratingSolar Thermal to Turbine: ", round(sum(results["CST"]["thermal_to_steamturbine_series_mmbtu_per_hour"]), digits = 2), " mmbtu")
        println("\tConcentratingSolar Thermal to All Hot Storage: ", round(sum(results["CST"]["thermal_to_storage_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tConcentratingSolar Thermal to HotSensibleTes: ", round(sum(results["CST"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println(results["CST"]["thermal_to_hot_sensible_tes_series_mmbtu_per_hour"][1:24])
        println("\tConcentratingSolar Thermal to Hot Water: ", round(sum(results["CST"]["thermal_to_dhw_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tConcentratingSolar Thermal to Space Heating: ", round(sum(results["CST"]["thermal_to_space_heating_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
        println("\tConcentratingSolar Thermal to Process Heat: ", round(sum(results["CST"]["thermal_to_process_heat_load_series_mmbtu_per_hour"]),digits = 2), " mmbtu")
    end
end

function power_flow_to_file(results, thermalfile="thermal_results.csv", elecfile="elec_results.csv")
    therm = open(thermalfile, "w")
    elec = open(elecfile, "w")
    write(therm, "t,")
    if "ExistingBoiler" in keys(results)
        write(therm, "BoilerToLoad,")
    end
    if "ElectricHeater" in keys(results)
        write(therm, "ElecHeaterToLoad,")
    end
    if "CST" in keys(results)
        write(therm, "CSTtoLoad,")
    end
    if "SteamTurbine" in keys(results)
        write(therm, "SteamTurbinetoLoad,")
    end
    if "HotSensibleTes" in keys(results)
        write(therm, "SensibleTEStoLoad,")
    end
    if "HotThermalStorage" in keys(results)
        write(therm, "HotTEStoLoad,")
    end
    if "CST" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
        write(therm, "CSTtoStorage,")
    end  
    if "ElectricHeater" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
        write(therm, "ElecHeatertoStorage,")
    end  
    if "SteamTurbine" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
        write(therm, "SteamTurbinetoStorage,")
    end
    if "ExistingBoiler" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
        write(therm, "BoilerToStorage,")
    end
    if "HotSensibleTes" in keys(results) || "HotThermalStorage" in keys(results)
        write(therm, "StorageSOC,")
    end
    write(therm,"\n")
    for ts in 1:8760
        write(therm, string(ts)*",")
        if "ExistingBoiler" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["ExistingBoiler"]["thermal_to_process_heat_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "ElectricHeater" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["ElectricHeater"]["thermal_to_process_heat_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "CST" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["CST"]["thermal_to_process_heat_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "SteamTurbine" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["SteamTurbine"]["thermal_to_process_heat_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "HotSensibleTes" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["HotSensibleTes"]["storage_to_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "HotThermalStorage" in keys(results)
            write(therm, string(REopt.KWH_PER_MMBTU*results["HotThermalStorage"]["storage_to_load_series_mmbtu_per_hour"][ts])*",")
        end
        if "CST" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
            write(therm, string(REopt.KWH_PER_MMBTU*results["CST"]["thermal_to_storage_series_mmbtu_per_hour"][ts])*",")
        end  
        if "ElectricHeater" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
            write(therm, string(REopt.KWH_PER_MMBTU*results["ElectricHeater"]["thermal_to_storage_series_mmbtu_per_hour"][ts])*",")
        end  
        if "SteamTurbine" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
            write(therm, string(REopt.KWH_PER_MMBTU*results["SteamTurbine"]["thermal_to_storage_series_mmbtu_per_hour"][ts])*",")
        end
        if "ExistingBoiler" in keys(results) && ("HotThermalStorage" in keys(results) || "HotSensibleTes" in keys(results))
            write(therm, string(REopt.KWH_PER_MMBTU*results["ExistingBoiler"]["thermal_to_storage_series_mmbtu_per_hour"][ts])*",")
        end
        if "HotSensibleTes" in keys(results)
            write(therm, string(results["HotSensibleTes"]["size_kwh"]*results["HotSensibleTes"]["soc_series_fraction"][ts])*",")
        end
        write(therm, "\n")
    end
    write(elec, "t,GridToLoad,")
    if "PV" in keys(results)
        write(elec, "PVtoLoad,")
    end
    if "SteamTurbine" in keys(results)
        write(elec, "SteamTurbineToElecLoad,")
    end
    if "ElectricStorage" in keys(results)
        write(elec, "BatteryToLoad,")
    end
    if "PV" in keys(results) && "ElectricStorage" in keys(results)
        write(elec, "PVtoStorage,")
    end
    if "SteamTurbine" in keys(results) && "ElectricStorage" in keys(results)
        write(elec, "SteamTurbineToStorage,")
    end
    if "ElectricStorage" in keys(results)
        write(elec, "GridToStorage,")
    end
    if "ElectricStorage" in keys(results)
        write(elec, "BatterySOC,")
    end
    write(elec, "\n")
    for ts in 1:8760
        write(elec, string(ts)*",")
        write(elec, string(results["ElectricUtility"]["electric_to_load_series_kw"][ts])*",")
        if "PV" in keys(results)
            write(elec, string(results["PV"]["electric_to_load_series_kw"][ts])*",")
        end
        if "SteamTurbine" in keys(results)
            write(elec, string(results["SteamTurbine"]["electric_to_load_series_kw"][ts])*",")
        end
        if "ElectricStorage" in keys(results)
            write(elec, string(results["ElectricStorage"]["storage_to_load_series_kw"][ts])*",")
        end
        if "PV" in keys(results) && "ElectricStorage" in keys(results)
            write(elec, string(results["PV"]["electric_to_storage_series_kw"][ts])*",")
        end
        if "SteamTurbine" in keys(results) && "ElectricStorage" in keys(results)
            write(elec, string(results["SteamTurbine"]["electric_to_storage_series_kw"][ts])*",")
        end
        if "ElectricStorage" in keys(results)
            write(therm, string(results["ElectricUtility"]["electric_to_storage_series_kw"][ts])*",")
        end
        if "ElectricStorage" in keys(results)
            write(therm, string(results["ElectricStorage"]["soc_series_fraction"][ts])*",")
        end
        write(elec, "\n")
    end
    close(elec)
    close(therm)
end

function power_flow_to_plot(results, t_start=24*150, t_end=24*153, outfile="thermal_results.png")
    labels = []
    data = Vector{Vector{Float64}()}
    if "ExistingBoiler" in keys(results)
        append!(labels, "BoilerToLoad")
        append!(data,results["ExistingBoiler"]["thermal_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "ElectricHeater" in keys(results)
        append!(labels, "ElecHeaterToLoad")
        append!(data,results["ElectricHeater"]["thermal_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "CST" in keys(results)
        append!(labels, "CSTtoLoad")
        append!(data,results["CST"]["thermal_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "SteamTurbine" in keys(results)
        append!(labels, "SteamTurbinetoLoad")
        append!(data,results["SteamTurbine"]["thermal_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "HotSensibleTes" in keys(results)
        append!(labels, "SensibleTEStoLoad")
        append!(data,results["HotSensibleTes"]["storage_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "HotThermalStorage" in keys(results)
        append!(labels, "HotTEStoLoad")
        append!(data,results["HotThermalStorage"]["storage_to_load_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "CST" in keys(results)
        append!(labels, "CSTtoStorage")
        append!(data,results["CST"]["thermal_to_storage_series_mmbtu_per_hour"][t_start:t_end])
    end  
    if "ElectricHeater" in keys(results)
        append!(labels, "ElecHeatertoStorage")
        append!(data,results["ElectricHeater"]["thermal_to_storage_series_mmbtu_per_hour"][t_start:t_end])
    end  
    if "SteamTurbine" in keys(results)
        append!(labels, "SteamTurbinetoStorage")
        append!(data,results["SteamTurbine"]["thermal_to_storage_series_mmbtu_per_hour"][t_start:t_end])
    end
    if "ExistingBoiler" in keys(results)
        append!(labels, "BoilerToStorage")
        append!(data,results["ExistingBoiler"]["thermal_to_storage_series_mmbtu_per_hour"][t_start:t_end])
    end
    #ticklabel = string.(collect(t_start:t_end))
    p = groupedbar(data,
            bar_position = :stack,
            bar_width=0.7,
            #xticks=(1:12, ticklabel),
            label=labels)
    savefig(p, outfile)
end

if false
    # Load in site and load information
    site_load = JSON.parsefile("siteLoad.json") # Enables consistent site and load for all cases

    # Technology cases
    pv_bat_eheater_case = merge(site_load, JSON.parsefile("pv_bat_eheater.json"))
    pv_bat_heatpump_case = merge(site_load, JSON.parsefile("pv_bat_heatpump.json"))


    m1 = Model(Cbc.Optimizer)
    m2 = Model(Cbc.Optimizer)
    eh_results = run_reopt([m1,m2], pv_bat_eheater_case)
    hp_results = run_reopt([m1,m2], pv_bat_heatpump_case)

    # Testing Ploting results
    ## https://docs.juliaplots.org/latest/tutorial/
    y = eh_results["PV"]["electric_to_storage_series_kw"][24*50:24*53]
    x = range(1, length(y), step = 1)
    # plot(x, y)
    println("elec to storage", y)
end

##Case 1: BAU

# d = JSON.parsefile("./scenarios/pv_PTES_with_process_heat_bau.json")
# d["ProcessHeatLoad"] = Dict()
# d["ElectricTariff"] = Dict()
# d["ElectricTariff"]["tou_energy_rates_per_kwh"] = ones(8760) .* 0.5
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* 100.0
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period
# for ts in 1:4380 #free electricity every other hour, expect the turbine to run to meet electricity when possible
#     d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][ts*2-1] = 0
#     d["ElectricTariff"]["tou_energy_rates_per_kwh"][ts*2-1] = 0
# end
# s = Scenario(d)
# p = REoptInputs(s)
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
# results = run_reopt(m1, p) # TODO: Get steam turbine working for electric load
# #results = run_reopt(m1, "pv_PTES_with_process_heat.json")


# println("Results of Case 1: Business as Usual (BAU)")
# print_results(results)


# ##Case 2: Only PV, Elecric Heater -> Hot Sensible TES
# d = JSON.parsefile("./scenarios/pv_PTES_with_process_heat_no_turbine.json")
# d["ProcessHeatLoad"] = Dict()
# d["ElectricTariff"] = Dict()
# d["ElectricTariff"]["tou_energy_rates_per_kwh"] = ones(8760) .* 0.5
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* 100.0
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period
# for ts in 1:4380 #free electricity and no heat load every other hour, expect the turbine to run to meet electricity and heat (?) when possible
#     d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][ts*2-1] = 0
#     d["ElectricTariff"]["tou_energy_rates_per_kwh"][ts*2-1] = 0
# end
# s = Scenario(d)
# p = REoptInputs(s)
# # println([p.s.electric_tariff.energy_rates[ts,1] for ts in 1:10])
# # m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => true, "log_to_console" => true, "mip_rel_gap" => 0.01))
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
# results = run_reopt(m1, p) # TODO: Get steam turbine working for electric load
# #results = run_reopt(m1, "pv_PTES_with_process_heat.json")
# println("Results of Case 2: Only PV, Elecric Heater -> Hot Sensible TES")
# print_results(results)

# ##Case 3: PV, Electric Heater -> Hot Sensible TES -> Steam Turbine OR Load

# d = JSON.parsefile("./scenarios/pv_PTES_with_process_heat_no_hot_tes.json")
# d["ProcessHeatLoad"] = Dict()
# d["ElectricTariff"] = Dict()
# d["ElectricTariff"]["tou_energy_rates_per_kwh"] = ones(8760) .* 0.5
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* 1.0
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period
# for ts in 1:4380 #free electricity and no heat load every other hour, expect the turbine to run to meet electricity and heat (?) when possible
#     d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][ts*2-1] = 0
#     d["ElectricTariff"]["tou_energy_rates_per_kwh"][ts*2-1] = 0
# end
# s = Scenario(d)
# p = REoptInputs(s)
# # println([p.s.electric_tariff.energy_rates[ts,1] for ts in 1:10])
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
# results = run_reopt(m1, p) # TODO: Get steam turbine working for electric load
# #results = run_reopt(m1, "pv_PTES_with_process_heat.json")
# # Print out solution
# # println(results["Messages"])
# println("Results of Case 3: PV, Electric Heater -> Hot Sensible TES -> Steam Turbine OR Load")
# print_results(results)

# ##Case 4: PV, Electric Heater, Hot Sensible TES, Steam Turbine, Hot Thermal Storage

# d = JSON.parsefile("./scenarios/pv_PTES_with_process_heat.json")
# d["ProcessHeatLoad"] = Dict()
# d["ElectricTariff"] = Dict()
# d["ElectricTariff"]["tou_energy_rates_per_kwh"] = ones(8760) .* 0.5
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* 1.0
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period
# for ts in 1:4380 #free electricity every other hour, expect the turbine to run to meet electricity when possible
#     d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][ts*2-1] = 0
#     d["ElectricTariff"]["tou_energy_rates_per_kwh"][ts*2-1] = 0
# end
# d["PV"]["max_kw"] = 100000.0
# s = Scenario(d)
# p = REoptInputs(s)
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
# results = run_reopt(m1, p) # TODO: Get steam turbine working for electric load
# #results = run_reopt(m1, "pv_PTES_with_process_heat.json")
# # println(results["Messages"])
# println("Results of Case 4: PV, Electric Heater, Hot Sensible TES, Steam Turbine, Hot Thermal Storage")
# print_results(results)

# # Case 5: Retire the boiler
# d["ExistingBoiler"]["retire_in_optimal"] = true
# s = Scenario(d)
# p = REoptInputs(s)
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
# results = run_reopt(m1, p) 
# #results = run_reopt(m1, "pv_PTES_with_process_heat.json")
# println(results["Messages"])
# println("Results of Case 5: Retire Boiler")
# print_results(results)


##Case 6: Only PV, Elecric Heater or CST -> Hot Sensible TES
d = JSON.parsefile("./scenarios/pv_cst_PTES_with_process_heat_no_turbine.json")
d["CST"]["elec_consumption_factor_series"] = zeros(8760)
d["CST"]["installed_cost_per_kw"] = 100.0
d["CST"]["min_kw"] = 1000
d["PV"]["min_kw"] = 1000
d["CST"]["max_kw"] = 1000
d["PV"]["max_kw"] = 1000
d["ProcessHeatLoad"] = Dict()
d["ElectricTariff"] = Dict()
d["ElectricTariff"]["tou_energy_rates_per_kwh"] = ones(8760) .* 0.5
d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"] = ones(8760) .* (500/0.8)/REopt.KWH_PER_MMBTU
# d["ProcessHeatLoad"]["fuel_loads_mmbtu_per_hour"][1] = 0.0  #initialize so that storage may charge in the first time period
s = Scenario(d)
p = REoptInputs(s)
# println([p.s.electric_tariff.energy_rates[ts,1] for ts in 1:10])
m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => true, "log_to_console" => true, "mip_rel_gap" => 0.01))
# m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 1, "MIPRELSTOP" => 0.01))
results = run_reopt(m1, p) # TODO: Get steam turbine working for electric load
#results = run_reopt(m1, "pv_PTES_with_process_heat.json")
println("Results of Case 6: Only PV, Electric Heater or CST -> Hot Sensible TES")
print_results(results)
power_flow_to_file(results)
# println("Attempting Plot save:")
# power_flow_to_plot(results)
# println("Plot saved.")

# start_day = 0
# end_day = 3
# # Energy flows into
# pv_gen = results["PV"]["electric_to_load_series_kw"][24*start_day + 1:24*end_day]


# time = range(1, length(pv_gen), step = 1)
# plot(time, pv_gen)




