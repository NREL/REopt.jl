# These packages are only needed to be loaded if using isolated from REopt
# using JSON
# using Dates

"""     
    convert_mgravens_inputs_to_reopt_inputs(mgravens::Dict)

- Load in the starting-point REopt inputs .json file (not a MG-Ravens user input) which has:
    1. All possible fields that may be extracted from the MG-Ravens .json schema into the REopt .json schema
    2. Default values for:
        a) Non-required but possible Ravens-input fields
        b) REopt inputs which are not exposed in Ravens (yet), customized to be for utility-scale MG's, different than standard REopt (C&I-scale)
- Build out REopt inputs by overwritting defaults or adding MG-Ravens inputs to REopt inputs
- Return the REopt inputs Dictionary
"""

# Notes for REopt
# Expecting a specific name for DesignAlgorithmProperties called DesignAlgorithmProperties_1 to get Financial.analysis_years
# Only looking at the first entry in ProposedSiteLocations for the site location
# Only using the first entry of LoadGroup.EnergyConsumers, but not really using EnergyConsumer for anything other than indexing on the LoadForecase
# Only using value1 for real power entries in the EnergyConsumerSchedule.RegularTimePoints list of dictionaries for load profile

function convert_mgravens_inputs_to_reopt_inputs(mgravens::Dict)
    reopt_inputs = JSON.parsefile(joinpath(@__DIR__, "..", "..", "data", "mgravens_fields_defaults.json"))

    # Assume any key within ProposedAssetOption.ProposedEnergyProducerOption are unique and compatible DERs to evaluate in REopt (and have the same site location, etc)
    tech_names = keys(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"])
    # TODO if there are duplicative DER types or incompatible DER types, throw an error

    # Analysis period
    lifetime_str = get(mgravens["AlgorithmProperties"]["DesignAlgorithmProperties"]["DesignAlgorithmProperties_1"], "DesignAlgorithmProperties.analysisPeriod", nothing)
    if !isnothing(lifetime_str)
        reopt_inputs["Financial"]["analysis_years"] = parse(Int64, split(split(lifetime_str, "P")[2], "Y")[1])
    end

    # Major assumptions: every ProposedEnergyProducerOption has the same SiteLocation, Region, and LoadGroup
    # TODO add error checking in case above is not true
    techs_to_include = []
    for (i, name) in enumerate(tech_names)
        tech_data = mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"][name]

        # Specific names that were given to certain categories/classes of data
        site_name = ""  # Only one, assumed to be the site location of the first ProposedAssetOption
        load_group_names = []  # May be one or more than one, e.g. ["ResidentialGroup", "IndustrialGroup"]
        energy_consumer_names = []  # One set (1+) for each LoadGroup, e.g. ["670a_residential2", "670b_residential2"]
        load_forecast_names = []  # One-to-one with energy_consumer_names
        region_name = ""
        lmp_name = ""
        capacity_prices_name = ""
        
        # Assign site, load, and energy prices attributes, using only the first ProducerOption because they **should** all be the same
        # TODO track all missing required inputs, and key optional inputs that rely on defaults
        if i == 1
            # Site data (lat, long, area) - lat/long is only needed if relying on PV or Wind APIs; default area is a Big Number
            site_name = tech_data["ProposedAssetOption.ProposedLocations"][1]
            land_sq_meter = get(mgravens["ProposedSiteLocations"][site_name], "ProposedSiteLocation.availableArea", nothing)
            if !isnothing(land_sq_meter)
                reopt_inputs["Site"]["land_acres"] = land_sq_meter / 4046.86
            end
            position_points = mgravens["ProposedSiteLocations"][site_name]["Location.PositionPoints"][1]
            reopt_inputs["Site"]["latitude"] = get(position_points, "PositionPoint.yPosition", nothing)
            reopt_inputs["Site"]["longitude"] = get(position_points, "PositionPoint.xPosition", nothing)
            # Also from SiteLocation, get needed references for 1) LoadGroup for load profile and 2) SubGeographicalRegion for energy prices
            load_groups_lumped = mgravens["ProposedSiteLocations"][site_name]["ProposedSiteLocation.LoadGroup"]
            # Have to extract just the name we want from lumped string value, e.g. "SubGeographicalRegion::'County1'" (want just 'County1')
            # Need to assume only one/first EnergyConsumer which is tied to a LoadForecast
            for load_group_lumped in load_groups_lumped
                load_group = replace(split(load_group_lumped, "::")[2], "'" => "")
                append!(load_group_names, [load_group])
                lumped_ec_list = mgravens["Group"]["LoadGroup"][load_group]["LoadGroup.EnergyConsumers"]
                for lumped_ec in lumped_ec_list
                    append!(energy_consumer_names, [replace(split(lumped_ec, "::")[2], "'" => "")])
                end
            end
            for energy_consumer_name in energy_consumer_names
                append!(load_forecast_names, [replace(split(mgravens["PowerSystemResource"]["Equipment"]["ConductingEquipment"]["EnergyConnection"]["EnergyConsumer"][energy_consumer_name]["EnergyConsumer.LoadProfile"], "::")[2], "'" => "")])
            end
            # ElectricLoad.loads_kw electric load profile - loop across all load_forecast_names and sum/aggregate/total them together
            # Need timestep_sec from ONE forecast for initializing loads_kw, but we do validation of timestep_sec and length of EACH load profile in the loop below
            timestep_sec = mgravens["BasicIntervalSchedule"][load_forecast_names[1]]["EnergyConsumerSchedule.timeStep"]
            reopt_inputs["Settings"]["time_steps_per_hour"] = 3600 / timestep_sec
            reopt_inputs["ElectricLoad"]["loads_kw"] = zeros(8760 * convert(Int64, reopt_inputs["Settings"]["time_steps_per_hour"]))
            # Sum up the loads in all load forecasts to aggregate into a single load profile
            for load_forecast_name in load_forecast_names
                load_forecast_dict = get(mgravens["BasicIntervalSchedule"], load_forecast_name, nothing)
                if !isnothing(load_forecast_dict)
                    # Currently allowing 24 hour, 168 hour, and 8760 hour load profile inputs and scaling to 1-year if not the full 8760
                    # TODO make sure it's consistent with prices by creating a "time_interval_length" variable to cross-check with all time-series input data
                    timestep_sec = load_forecast_dict["EnergyConsumerSchedule.timeStep"]
                    if !(timestep_sec in [900, 3600])
                        throw(@error("Valid EnergyConsumerSchedule.timeStep for BasicIntervalSchedule LoadForecast is 900 and 3600, input of $timestep_sec"))
                    end
                    load_list_of_dict = load_forecast_dict["EnergyConsumerSchedule.RegularTimePoints"]
                    # TODO make appending shorter horizon load data to make 8760 more efficient than below which is appending many many dictionaries
                    #   instead, make an array of e.g. length 24, and then append just the numbers to get 8760 before assigning to loads_kw
                    # if length(load_list_of_dict) == 24
                    #     for _ in 1:364
                    #         append!(load_list_of_dict, load_forecast_dict["EnergyConsumerSchedule.RegularTimePoints"])
                    #     end
                    # elseif length(load_list_of_dict) == 168
                    #     for _ in 1:52
                    #         append!(load_list_of_dict, load_forecast_dict["EnergyConsumerSchedule.RegularTimePoints"])
                    #     end
                    #     # Have to add one more day's worth of time, so take the first 24 hours of the week again for the last 24 hours of the 8760
                    #     append!(load_list_of_dict, load_forecast_dict["EnergyConsumerSchedule.RegularTimePoints"][1:24])           
                    # elseif !(length(load_list_of_dict) in [8760, 35040])
                    #     throw(@error("Valid length of load forecast data is 24, 168, or 8760"))
                    # end
                    for (ts, data) in enumerate(load_list_of_dict)
                        # Ignoring value2 which is "VAr" (reactive power)
                        reopt_inputs["ElectricLoad"]["loads_kw"][ts] += data["RegularTimePoint.value1"]
                    end
                else
                    throw(@error("No $load_forecast_name load_forecast_name found in BasicIntervalSchedule"))
                end
            end

            # A bunch of financial/prices stuff depends on the Region name, but this is all assumed to apply for all/aggregate loads
            subregion_name = replace(split(mgravens["ProposedSiteLocations"][site_name]["ProposedSiteLocation.Region"], "::")[2], "'" => "")
            region_name = replace(split(mgravens["Group"]["SubGeographicalRegion"][subregion_name]["SubGeographicalRegion.Region"], "::")[2], "'" => "")
            region_dict = mgravens["Group"]["GeographicalRegion"][region_name]["GeographicalRegion.Regions"][1]
            
            # Financial inputs (optional)
            financial_map = [("discountRate", "offtaker_discount_rate_fraction"), 
                            ("inflationRate", "om_cost_escalation_rate_fraction"),
                            ("taxRate", "offtaker_tax_rate_fraction")]
            economic_props = region_dict["Regions.EconomicProperty"]
            for param in financial_map
                if !isnothing(get(economic_props, "EconomicProperty."*param[1], nothing))
                    reopt_inputs["Financial"][param[2]] = round(economic_props["EconomicProperty."*param[1]] / 100.0, digits=4)  # Convert percent to decimal
                end
            end

            # LMP - energy prices
            lmp_name = replace(split(region_dict["Regions.EnergyPrices"]["EnergyPrices.LocationalMarginalPrices"], "::")[2], "'" => "")
            lmp_dict = get(mgravens["EnergyPrices"]["LocationalMarginalPrices"], lmp_name, nothing)
            if !isnothing(lmp_dict)
                # LMP - energy prices
                lmp_list_of_dict = lmp_dict["LocationalMarginalPrices.LMPCurve"]["PriceCurve.CurveDatas"]
                # Note, if 15-minute interval analysis, must supply LMPs in 15-minute interval, so they have one-to-one data
                reopt_inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = zeros(8760 * convert(Int64, reopt_inputs["Settings"]["time_steps_per_hour"]))
                # reopt_inputs["ElectricTariff"]["wholesale_rate"] = zeros(8760 * convert(Int64, reopt_inputs["Settings"]["time_steps_per_hour"]))
                # TODO allow e.g. list of 24 (1-day) and 168 hour (1-week) for LMP if the load forecast is also 24/168, and just replicate e.g. 365/52 times
                if length(lmp_list_of_dict) == length(reopt_inputs["ElectricLoad"]["loads_kw"])
                    for (ts, data) in enumerate(lmp_list_of_dict)
                        reopt_inputs["ElectricTariff"]["tou_energy_rates_per_kwh"][ts] = data["CurveData.y1value"]
                        # reopt_inputs["ElectricTariff"]["wholesale_rate"][ts] = data["CurveData.y1value"]
                    end                    
                else
                    throw(@error("Interval of Load RegularIntervalSchedule.TimePoints must match the interval of LMP PriceCurve.CurveDatas"))
                end
            else
                throw(@error("No LMP name $lmp_name found in EnergyPrices.LocationalMarginalPrices"))
            end

            # Capacity prices (monthly)
            capacity_prices_name = replace(split(region_dict["Regions.EnergyPrices"]["EnergyPrices.CapacityPrices"], "::")[2], "'" => "")
            capacity_dict = get(mgravens["EnergyPrices"]["CapacityPrices"], capacity_prices_name, nothing)
            if !isnothing(capacity_dict)
                capacity_list_of_dict = capacity_dict["CapacityPrices.CapacityPriceCurve"]["PriceCurve.CurveDatas"]
                if length(capacity_list_of_dict) == 12
                    reopt_inputs["ElectricTariff"]["monthly_demand_rates"] = zeros(12)
                    for (ts, data) in enumerate(capacity_list_of_dict)
                        reopt_inputs["ElectricTariff"]["monthly_demand_rates"][ts] = data["CurveData.y1value"]
                    end
                else
                    throw(@error("Length of CapacityPrices PriceCurve.CurveDatas must be equal to 12 (monthly)"))
                end
            else
                throw(@error("No Capacity name $capacity_prices_name found in EnergyPrices.CapacityPrices"))
            end

            # Printing for debugging
            # println("")
            # println("site_name = $site_name")
            # println("load_group_names = $load_group_names")
            # println("energy_consumer_names = $energy_consumer_names")
            # println("load_forecast_names = $load_forecast_names")
            # println("subregion_name = $subregion_name")
            # println("region_name = $region_name")
            # println("lmp_name = $lmp_name")
            # println("capacity_prices_name = $capacity_prices_name")

            # Outages: NOTE, REopt cannot consider different outage durations for differerent outage start times
            #   it can only consider the same set of outage durations with their specified probabilities (sum equals one) across ALL outage start times
            #   also can only specify ONE fraction of total load for critical load
            duration = []  # Only a list to take average at the end (assuming different)
            critical_load_fraction = []  # Only a list to take average at the end (assuming different)
            outage_start_time_steps = []
            for outage in keys(get(mgravens, "OutageScenario", []))
                duration_str = mgravens["OutageScenario"][outage]["OutageScenario.anticipatedDuration"]
                append!(duration, [parse(Int64, split(split(duration_str, "P")[2], "H")[1])])
                append!(critical_load_fraction, [mgravens["OutageScenario"][outage]["OutageScenario.loadFractionCritical"] / 100.0])
                start_date_str = get(mgravens["OutageScenario"][outage], "OutageScenario.anticipatedStartDay", nothing)
                # Optional to input start date and hour, and otherwise REopt will use default 4 seasonal peak outages
                if !isnothing(start_date_str)
                    # TODO what year is it? For now, assume 2024. Doesn't matter as long as load aligns with LMPs
                    year = 2024        
                    reopt_inputs["ElectricLoad"]["year"] = year
                    monthly_time_steps = get_monthly_time_steps(year; time_steps_per_hour = convert(Int64, reopt_inputs["Settings"]["time_steps_per_hour"]))
                    start_month = parse(Int64, split(start_date_str, "-")[3])
                    start_day_of_month = parse(Int64, split(start_date_str, "-")[4])
                    start_hour_of_day = mgravens["OutageScenario"][outage]["OutageScenario.anticipatedStartHour"]
                    append!(outage_start_time_steps, [monthly_time_steps[start_month][(start_day_of_month - 1) * 24 + start_hour_of_day]])
                end
            end
            duration_avg = convert(Int64, round(sum(duration) / length(duration), digits=0))
            critical_load_fraction_avg = sum(critical_load_fraction) / length(critical_load_fraction)
            reopt_inputs["ElectricUtility"]["outage_durations"] = [duration_avg]
            reopt_inputs["Site"]["min_resil_time_steps"] = duration_avg
            # TODO, figure out if this is right: the get_monthly_time_steps is cutting out the leap day timesteps, while the REopt model may be cutting off 12/31
            #  If user inputs 2024 load data, including the lead day load shouldn't we include the leap day for outage_start_time_steps?
            #  The most important thing is aligning the energy costs with the load
            if !isempty(outage_start_time_steps)
                reopt_inputs["ElectricUtility"]["outage_start_time_steps"] = outage_start_time_steps
            end
            reopt_inputs["ElectricLoad"]["critical_load_fraction"] = critical_load_fraction_avg
        end

        # Technology specific input parameters
        if tech_data["Ravens.CimObjectType"] == "ProposedPhotovoltaicUnitOption"
            # PV inputs
            append!(techs_to_include, ["PV"])
            # Optional inputs for PV; only update if included in MG-Ravens inputs, otherwise rely on MG-Ravens default or REopt default
            if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityFixed", nothing))
                reopt_inputs["PV"]["min_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityFixed"]
                reopt_inputs["PV"]["max_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityFixed"]
            else
                if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityMin", nothing))
                    reopt_inputs["PV"]["min_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityMin"]
                end
                if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityMax", nothing))
                    reopt_inputs["PV"]["max_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityMax"]
                end
            end
            if !isnothing(get(tech_data, "ProposedEnergyProducerOption.variablePrice", nothing))
                reopt_inputs["PV"]["installed_cost_per_kw"] = tech_data["ProposedEnergyProducerOption.variablePrice"]["value"]
            end
            if !isnothing(get(tech_data, "ProposedEnergyProducerOption.operationsAndMaintenanceRateFixed", nothing))
                reopt_inputs["PV"]["om_cost_per_kw"] = tech_data["ProposedEnergyProducerOption.operationsAndMaintenanceRateFixed"]["value"]
            end
            if !isnothing(get(tech_data, "ProposedPhotovoltaicUnitOption.GenerationProfile", nothing))
                reopt_inputs["PV"]["production_factor_series"] = zeros(8760 * convert(Int64, reopt_inputs["Settings"]["time_steps_per_hour"]))
                for (i, data) in enumerate(tech_data["ProposedPhotovoltaicUnitOption.GenerationProfile"]["Curve.CurveDatas"])
                    reopt_inputs["PV"]["production_factor_series"][i] = data["CurveData.y1value"]
                end
            end
        elseif tech_data["Ravens.CimObjectType"] == "ProposedBatteryUnitOption"
            append!(techs_to_include, ["ElectricStorage"])
            # Optional inputs for ElectricStorage; only update if included in MG-Ravens inputs, otherwise rely on MG-Ravens default or REopt default
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.energyCapacityFixed", nothing))
                reopt_inputs["ElectricStorage"]["min_kwh"] = tech_data["ProposedBatteryUnitOption.energyCapacityFixed"]
                reopt_inputs["ElectricStorage"]["max_kwh"] = tech_data["ProposedBatteryUnitOption.energyCapacityFixed"]
            else
                if !isnothing(get(tech_data, "ProposedBatteryUnitOption.energyCapacityMin", nothing))
                    reopt_inputs["ElectricStorage"]["min_kwh"] = tech_data["ProposedBatteryUnitOption.energyCapacityMin"]
                end
                if !isnothing(get(tech_data, "ProposedBatteryUnitOption.energyCapacityMax", nothing))
                    reopt_inputs["ElectricStorage"]["max_kwh"] = tech_data["ProposedBatteryUnitOption.energyCapacityMax"]
                end
            end
            if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityFixed", nothing))
                reopt_inputs["ElectricStorage"]["min_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityFixed"]
                reopt_inputs["ElectricStorage"]["max_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityFixed"]
            else
                if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityMin", nothing))
                    reopt_inputs["ElectricStorage"]["min_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityMin"]
                end
                if !isnothing(get(tech_data, "ProposedEnergyProducerOption.powerCapacityMax", nothing))
                    reopt_inputs["ElectricStorage"]["max_kw"] = tech_data["ProposedEnergyProducerOption.powerCapacityMax"]
                end
            end          
            if !isnothing(get(tech_data, "ProposedAssetOption.variablePrice", nothing))
                reopt_inputs["ElectricStorage"]["installed_cost_per_kw"] = tech_data["ProposedAssetOption.variablePrice"]["value"]
                # Assume replacement cost is 50% of first cost, and replacement happens at half way through the analysis period years
                reopt_inputs["ElectricStorage"]["replace_cost_per_kw"] = 0.5 * reopt_inputs["ElectricStorage"]["installed_cost_per_kw"]
                reopt_inputs["ElectricStorage"]["inverter_replacement_year"] = convert(Int64, floor(0.5 * reopt_inputs["Financial"]["analysis_years"], digits=0))
            end
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.variableEnergyPrice", nothing))
                reopt_inputs["ElectricStorage"]["installed_cost_per_kwh"] = tech_data["ProposedBatteryUnitOption.variableEnergyPrice"]["value"]
                reopt_inputs["ElectricStorage"]["replace_cost_per_kwh"] = 0.5 * reopt_inputs["ElectricStorage"]["installed_cost_per_kwh"]
                reopt_inputs["ElectricStorage"]["battery_replacement_year"] = convert(Int64, floor(0.5 * reopt_inputs["Financial"]["analysis_years"], digits=0))
            end
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.stateOfChargeMin", nothing))
                reopt_inputs["ElectricStorage"]["soc_min_fraction"] = tech_data["ProposedBatteryUnitOption.stateOfChargeMin"] / 100.0
            end
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.chargeEfficiency", nothing))
                reopt_inputs["ElectricStorage"]["rectifier_efficiency_fraction"] = tech_data["ProposedBatteryUnitOption.chargeEfficiency"] / 100.0
            end
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.dischargeEfficiency", nothing))
                reopt_inputs["ElectricStorage"]["inverter_efficiency_fraction"] = tech_data["ProposedBatteryUnitOption.dischargeEfficiency"] / 100.0
            end
            # Since REopt has rectifier, internal, and inverter efficiencies, assign charge to rectifier, discharge to inverter, and internal to 1.0
            if !isnothing(get(tech_data, "ProposedBatteryUnitOption.chargeEfficiency", nothing)) && !isnothing(get(tech_data, "ProposedBatteryUnitOption.dischargeEfficiency", nothing))
                reopt_inputs["ElectricStorage"]["internal_efficiency_fraction"] = 1.0     
            end
        end
    end

    non_tech_keys = ["Site", "ElectricLoad", "ElectricTariff", "ElectricUtility", "Financial", "Settings"]

    # Remove technologies that are in the base mgravens_fields_defaults.json file that are not included in this analysis scenario
    for key in keys(reopt_inputs)
        if !(key in non_tech_keys) && !(key in techs_to_include)
            pop!(reopt_inputs, key)
        end
    end

    return reopt_inputs
end


function update_mgravens_with_reopt_results!(reopt_results::Dict, mgravens::Dict)
    # Convert from REopt --> MG-Ravens outputs and update or add fields to MG-Ravens data .json
    # We are NOT creating a separate mgravens.json - only adding or maybe updating values (but mostly adding)
    # Three main sections we are adding: 1) "Group.ProposedAssetSet.[BAU and Optimal]", 2) Group.EstimatedAssetCosts.[BAU and Optimal], and 
    #  3) ProposedAssets.[Each Technology]

    # Add any warning or error messages in the top-level "Message" list of dictionaries
    mgravens["Message"] =  [
        Dict(
          "IdentifiedObject.mRID" => string(uuid4()),
          "Ravens.CimObjectType" => "Warning",
          "Message.message" => string(reopt_results["Messages"]["warnings"]),
          "Message.Application" => Dict("Application.applicationName" => "REopt")
        ),
        Dict(
            "IdentifiedObject.mRID" => string(uuid4()),
            "Ravens.CimObjectType" => "Error",
            "Message.message" => string(reopt_results["Messages"]["errors"]),
            "Message.Application" => Dict("Application.applicationName" => "REopt")
          ),
    ]

    # Start by adding the output/results Dicts, if needed
    if !("EstimatedAssetCosts" in keys(mgravens))
        mgravens["EstimatedAssetCosts"] = Dict{String, Any}()
    end

    if !("ProposedAssetSet" in keys(mgravens["Group"]))
        mgravens["Group"]["ProposedAssetSet"] = Dict{String, Any}()
    end

    # Create Group.ProposedAssetSet and Group.EstimatedAssetCosts for BAU and Optimal
    scenario_names = ["BusinessAsUsual", "Optimal"]

    # ProposedAssetSet will also get populated with the list of ProposedAssetSet.ProposedAssets depending on which technologies were included
    for scenario_name in scenario_names
        proposed_asset_set_uuid = string(uuid4())
        mgravens["Group"]["ProposedAssetSet"][scenario_name] = Dict{String, Any}(
            "IdentifiedObject.name"=> scenario_name,
            "IdentifiedObject.mRID"=> proposed_asset_set_uuid,
            "Ravens.CimObjectType"=> "ProposedAssetSet",
            "ProposedAssetSet.ProposedAssets"=> [],
            "ProposedAssetSet.Application" => "Application::'REopt'",
            "ProposedAssetSet.EstimatedCosts" => "EstimatedEnergyProducerAssetCosts::'$scenario_name'"
        )

        # Scenario total lifecycle costs
        bau_suffix = ""  # blank for optimal scenario
        npv = 0.0  # 0.0 for BAU
        lcc_capital_costs = 0.0  # 0.0 for BAU
        if scenario_name == "BusinessAsUsual"
            bau_suffix = "_bau"
        else
            npv = reopt_results["Financial"]["npv"]
            lcc_capital_costs = reopt_results["Financial"]["lifecycle_capital_costs"]
        end
            
        estimated_asset_costs_uuid = string(uuid4())
        mgravens["EstimatedAssetCosts"][scenario_name] = Dict{String, Any}(
            "IdentifiedObject.name" => scenario_name,
            "IdentifiedObject.mRID" => estimated_asset_costs_uuid,
            "Ravens.CimObjectType" => "EstimatedEnergyProducerAssetCosts",
            "EstimatedEnergyProducerAssetCosts.lifecycleCapacityCost" => reopt_results["ElectricTariff"]["lifecycle_demand_cost_after_tax"*bau_suffix],
            "EstimatedEnergyProducerAssetCosts.lifecycleEnergyCost" => reopt_results["ElectricTariff"]["lifecycle_energy_cost_after_tax"*bau_suffix],
            "EstimatedEnergyProducerAssetCosts.lifecycleCapitalCost" => lcc_capital_costs,
            "EstimatedEnergyProducerAssetCosts.lifecycleCost" => reopt_results["Financial"]["lcc"*bau_suffix],
            "EstimatedEnergyProducerAssetCosts.netPresentValue" => npv
        )
    end


    # Technology-specific outputs; need to append possible_techs once more are added to the mg-ravens conversions
    # TODO ask why we don't just name the ProposedAsset the same as the ProposedAssetOption?
    possible_techs = [("PV", "REopt_PV"), ("ElectricStorage", "REopt_ESS")]
    tech_names = []
    for tech in possible_techs
        if tech[1] in keys(reopt_results)
            append!(tech_names, [tech[2]])
        end
    end

    # Find the unique tech names that associate with the different possible techs
    ravens_tech_names = keys(mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"])
    tech_name_map = Dict(map[1] => "" for map in possible_techs)
    for tech in ravens_tech_names
        tech_data = mgravens["ProposedAssetOption"]["ProposedEnergyProducerOption"][tech]
        if tech_data["Ravens.CimObjectType"] == "ProposedPhotovoltaicUnitOption"
            tech_name_map["PV"] = tech
        elseif tech_data["Ravens.CimObjectType"] == "ProposedBatteryUnitOption"
            tech_name_map["ElectricStorage"] = tech
        end
    end

    # This loop is associating all technologies with the Optimal scenario only, as indicated by "ProposedAsset.EstimatedCosts": "EstimatedEnergyProducerAssetCosts::"*scenario_name[2]
    for (i, name) in enumerate(tech_names)

        if !("ProposedAsset" in keys(mgravens))
            mgravens["ProposedAsset"] = Dict{String, Any}()
        end
        
        # Filling in results for each technology
        proposed_asset_uuid = string(uuid4())
        proposed_asset_template = Dict{String, Any}(
            "IdentifiedObject.name" => name,
            "IdentifiedObject.mRID" => proposed_asset_uuid,
            "Ravens.CimObjectType" => "",  # To be filled in depending on which technology type
            "ProposedAsset.ProposedAssetOption" => "",
            "ProposedAsset.EstimatedCosts" => "EstimatedEnergyProducerAssetCosts::'"*scenario_names[2]*"'",
        )

        if occursin("PV", name)
            # Add PV stuff
            append!(mgravens["Group"]["ProposedAssetSet"][scenario_names[2]]["ProposedAssetSet.ProposedAssets"], ["ProposedEnergyProducerAsset::'$name'"])
            proposed_asset_template["ProposedEnergyProducerAsset.capacity"] = reopt_results["PV"]["size_kw"]
            proposed_asset_template["Ravens.CimObjectType"] = "ProposedEnergyProducerAsset"
            proposed_asset_template["ProposedAsset.ProposedAssetOption"] = "ProposedPhotovoltaicUnitOption::'"*tech_name_map["PV"]*"'"
            proposed_asset_template["ProposedEnergyProducerAsset.PowerDispatchCurve"] = Dict{String, Any}(
                "IdentifiedObject.name" => "PVProfile",
                "IdentifiedObject.mRID" => string(uuid4()),
                "Ravens.CimObjectType" => "DispatchCurve",
                "Curve.xUnit" => "h",
                "Curve.CurveDatas" => []
                )
            for ts in 1:8760
                append!(proposed_asset_template["ProposedEnergyProducerAsset.PowerDispatchCurve"]["Curve.CurveDatas"], 
                [Dict("CurveData.xvalue" => ts-1, "CurveData.y1value" => reopt_results["PV"]["production_factor_series"][ts])])
            end
        elseif occursin("ESS", name)
            # Add Battery stuff
            append!(mgravens["Group"]["ProposedAssetSet"][scenario_names[2]]["ProposedAssetSet.ProposedAssets"], ["ProposedBatteryUnit::'$name'"])
            proposed_asset_template["Ravens.CimObjectType"] = "ProposedBatteryUnit"
            proposed_asset_template["ProposedAsset.ProposedAssetOption"] = "ProposedBatteryUnitOption::'"*tech_name_map["ElectricStorage"]*"'"
            proposed_asset_template["ProposedEnergyProducerAsset.capacity"] = reopt_results["ElectricStorage"]["size_kw"]
            proposed_asset_template["ProposedBatteryUnit.energyCapacity"] = reopt_results["ElectricStorage"]["size_kwh"]

            # TODO add dispatch for Battery, even if used as a target/reference set point
        end

        mgravens["ProposedAsset"][name] = proposed_asset_template
    end   
end


# THIS FUNCTION WAS COPIED FROM REOPT.JL UTILS.JL
"""
    get_monthly_time_steps(year::Int; time_steps_per_hour=1)

return Array{Array{Int64,1},1}, size = (12,)
"""
function get_monthly_time_steps(year::Int; time_steps_per_hour=1)
    a = Array[]
    i = 1
    for m in range(1, stop=12)
        n_days = daysinmonth(Date(string(year) * "-" * string(m)))
        stop = n_days * 24 * time_steps_per_hour + i - 1
        if m == 2 && isleapyear(year)
            stop -= 24 * time_steps_per_hour  # TODO support extra day in leap years?
        end
        steps = [step for step in range(i, stop=stop)]
        append!(a, [steps])
        i = stop + 1
    end
    return a
end