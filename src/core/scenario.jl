# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
struct Scenario <: AbstractScenario
    settings::Settings
    site::Site
    pvs::Array{PV, 1}
    wind::Wind
    storage::Storage
    electric_tariff::ElectricTariff
    electric_load::ElectricLoad
    electric_utility::ElectricUtility
    financial::Financial
    generator::Generator
    dhw_load::DomesticHotWaterLoad
    space_heating_load::SpaceHeatingLoad
    cooling_load::CoolingLoad
    existing_boiler::Union{ExistingBoiler, Nothing}
    boiler::Union{Boiler, Nothing}
    chp::Union{CHP, Nothing}  # use nothing for more items when they are not modeled?
    flexible_hvac::Union{FlexibleHVAC, Nothing}
    existing_chiller::Union{ExistingChiller, Nothing}
    absorption_chiller::Union{AbsorptionChiller, Nothing}
    ghp_option_list::Array{Union{GHP, Nothing}, 1}  # List of GHP objects (often just 1 element, but can be more)
    heating_thermal_load_reduction_with_ghp_kw::Union{Vector{Float64}, Nothing}
    cooling_thermal_load_reduction_with_ghp_kw::Union{Vector{Float64}, Nothing}
    steam_turbine::Union{SteamTurbine, Nothing}
end

"""
    Scenario(d::Dict; flex_hvac_from_json=false)

A Scenario struct can contain the following keys:
- [Site](@ref) (required)
- [Financial](@ref) (optional)
- [ElectricTariff](@ref) (required when `off_grid_flag=false`)
- [ElectricLoad](@ref) (required)
- [PV](@ref) (optional, can be Array)
- [Wind](@ref) (optional)
- [ElectricStorage](@ref) (optional)
- [ElectricUtility](@ref) (optional)
- [Generator](@ref) (optional)
- [DomesticHotWaterLoad](@ref) (optional)
- [SpaceHeatingLoad](@ref) (optional)
- [ExistingBoiler](@ref) (optional)
- [Boiler](@ref) (optional)
- [CHP](@ref) (optional)
- [FlexibleHVAC](@ref) (optional)
- [ExistingChiller](@ref) (optional)
- [AbsorptionChiller](@ref) (optional)
- [GHP](@ref) (optional, can be Array)
- [SteamTurbine](@ref) (optional)

All values of `d` are expected to be `Dicts` except for `PV` and `GHP`, which can be either a `Dict` or `Dict[]` (for multiple PV arrays or GHP options).

!!! note 
    Set `flex_hvac_from_json=true` if `FlexibleHVAC` values were loaded in from JSON (necessary to 
    handle conversion of Vector of Vectors from JSON to a Matrix in Julia).
"""
function Scenario(d::Dict; flex_hvac_from_json=false)
    d = deepcopy(d)
    if haskey(d, "Settings")
        settings = Settings(;dictkeys_tosymbols(d["Settings"])...)
    else
        settings = Settings()
    end
    
    site = Site(;dictkeys_tosymbols(d["Site"])...)

    # Check that only PV, electric storage, and generator are modeled for off-grid
    if settings.off_grid_flag
        offgrid_allowed_keys = ["PV", "Wind", "ElectricStorage", "Generator", "Settings", "Site", "Financial", "ElectricLoad", "ElectricTariff", "ElectricUtility"]
        unallowed_keys = setdiff(keys(d), offgrid_allowed_keys) 
        if !isempty(unallowed_keys)
            error("Currently, only PV, ElectricStorage, and Generator can be modeled when off_grid_flag is true. Cannot model $unallowed_keys.")
        end
    end
    
    pvs = PV[]
    if haskey(d, "PV")
        if typeof(d["PV"]) <: AbstractArray
            for (i, pv) in enumerate(d["PV"])
                if !(haskey(pv, "name"))
                    pv["name"] = string("PV", i)
                end
                push!(pvs, PV(;dictkeys_tosymbols(pv)..., off_grid_flag = settings.off_grid_flag, 
                            latitude=site.latitude))
            end
        elseif typeof(d["PV"]) <: AbstractDict
            push!(pvs, PV(;dictkeys_tosymbols(d["PV"])..., off_grid_flag = settings.off_grid_flag, 
                        latitude=site.latitude))
        else
            error("PV input must be Dict or Dict[].")
        end
    end

    if haskey(d, "Financial")
        financial = Financial(; dictkeys_tosymbols(d["Financial"])...,
                                latitude=site.latitude, longitude=site.longitude, 
                                off_grid_flag = settings.off_grid_flag,
                                include_health_in_objective = settings.include_health_in_objective
                            )
    else
        financial = Financial(; latitude=site.latitude, longitude=site.longitude,
                                off_grid_flag = settings.off_grid_flag
                            )
    end

    if haskey(d, "ElectricUtility") && !(settings.off_grid_flag)
        electric_utility = ElectricUtility(; dictkeys_tosymbols(d["ElectricUtility"])...,
                                            latitude=site.latitude, longitude=site.longitude, 
                                            CO2_emissions_reduction_min_fraction=site.CO2_emissions_reduction_min_fraction,
                                            CO2_emissions_reduction_max_fraction=site.CO2_emissions_reduction_max_fraction,
                                            include_climate_in_objective=settings.include_climate_in_objective,
                                            include_health_in_objective=settings.include_health_in_objective,
                                            off_grid_flag=settings.off_grid_flag,
                                            time_steps_per_hour=settings.time_steps_per_hour
                                        )
    elseif !(settings.off_grid_flag)
        electric_utility = ElectricUtility(; latitude=site.latitude, longitude=site.longitude, 
                                            time_steps_per_hour=settings.time_steps_per_hour
                                        )
    elseif settings.off_grid_flag 
        if haskey(d, "ElectricUtility")
            @warn "ElectricUtility inputs are not applicable when off_grid_flag is true and any ElectricUtility inputs will be ignored. For off-grid scenarios, a year-long outage will always be modeled."
        end
        electric_utility = ElectricUtility(; outage_start_time_step = 1, 
                                            outage_end_time_step = settings.time_steps_per_hour * 8760, 
                                            latitude=site.latitude, longitude=site.longitude, 
                                            time_steps_per_hour=settings.time_steps_per_hour
                                        ) 
    end
        
    storage_structs = Dict{String, AbstractStorage}()
    if haskey(d,  "ElectricStorage")
        storage_dict = dictkeys_tosymbols(d["ElectricStorage"])
        storage_dict[:off_grid_flag] = settings.off_grid_flag
    else
        storage_dict = Dict(:max_kw => 0.0) 
    end
    storage_structs["ElectricStorage"] = ElectricStorage(storage_dict, financial)
    # TODO stop building ElectricStorage when it is not modeled by user 
    #       (requires significant changes to constraints, variables)
    if haskey(d, "HotThermalStorage")
        params = HotThermalStorageDefaults(; dictkeys_tosymbols(d["HotThermalStorage"])...)
        storage_structs["HotThermalStorage"] = ThermalStorage(params, financial, settings.time_steps_per_hour)
    end
    if haskey(d, "ColdThermalStorage")
        params = ColdThermalStorageDefaults(; dictkeys_tosymbols(d["ColdThermalStorage"])...)
        storage_structs["ColdThermalStorage"] = ThermalStorage(params, financial, settings.time_steps_per_hour)
    end
    storage = Storage(storage_structs)

    electric_load = ElectricLoad(; dictkeys_tosymbols(d["ElectricLoad"])...,
                                   latitude=site.latitude, longitude=site.longitude, 
                                   time_steps_per_hour=settings.time_steps_per_hour,
                                   off_grid_flag = settings.off_grid_flag
                                )

    if !(settings.off_grid_flag) # ElectricTariff only required for on-grid                            
        electric_tariff = ElectricTariff(; dictkeys_tosymbols(d["ElectricTariff"])..., 
                                        year=electric_load.year,
                                        NEM=electric_utility.net_metering_limit_kw > 0, 
                                        time_steps_per_hour=settings.time_steps_per_hour
                                        )
    else # if ElectricTariff inputs supplied for off-grid, will not be applied. 
        if haskey(d, "ElectricTariff")
            @warn "ElectricTariff inputs are not applicable when off_grid_flag is true, and will be ignored."
        end
        electric_tariff = ElectricTariff(;  blended_annual_energy_rate = 0.0, 
                                            blended_annual_demand_rate = 0.0,
                                            year=electric_load.year,
                                            time_steps_per_hour=settings.time_steps_per_hour
        )
    end

    if haskey(d, "Wind")
        wind = Wind(; dictkeys_tosymbols(d["Wind"])..., off_grid_flag=settings.off_grid_flag,
                    average_elec_load=sum(electric_load.loads_kw) / length(electric_load.loads_kw))
    else
        wind = Wind(; max_kw=0)
    end

    if haskey(d, "Generator")
        generator = Generator(; dictkeys_tosymbols(d["Generator"])..., off_grid_flag=settings.off_grid_flag, analysis_years=financial.analysis_years)
    else
        generator = Generator(; max_kw=0)
    end

    max_heat_demand_kw = 0.0
    if haskey(d, "DomesticHotWaterLoad") && !haskey(d, "FlexibleHVAC")
        add_doe_reference_names_from_elec_to_thermal_loads(d["ElectricLoad"], d["DomesticHotWaterLoad"])
        dhw_load = DomesticHotWaterLoad(; dictkeys_tosymbols(d["DomesticHotWaterLoad"])...,
                                          latitude=site.latitude, longitude=site.longitude, 
                                          time_steps_per_hour=settings.time_steps_per_hour
                                        )
        max_heat_demand_kw = maximum(dhw_load.loads_kw)
    else
        dhw_load = DomesticHotWaterLoad(; 
            fuel_loads_mmbtu_per_hour=zeros(8760*settings.time_steps_per_hour),
            time_steps_per_hour=settings.time_steps_per_hour
        )
    end
                                    
    if haskey(d, "SpaceHeatingLoad") && !haskey(d, "FlexibleHVAC")
        add_doe_reference_names_from_elec_to_thermal_loads(d["ElectricLoad"], d["SpaceHeatingLoad"])
        space_heating_load = SpaceHeatingLoad(; dictkeys_tosymbols(d["SpaceHeatingLoad"])...,
                                                latitude=site.latitude, longitude=site.longitude, 
                                                time_steps_per_hour=settings.time_steps_per_hour
                                              )
        
        max_heat_demand_kw = maximum(space_heating_load.loads_kw .+ max_heat_demand_kw)
    else
        space_heating_load = SpaceHeatingLoad(; 
            fuel_loads_mmbtu_per_hour=zeros(8760*settings.time_steps_per_hour),
            time_steps_per_hour=settings.time_steps_per_hour
        )
    end

    flexible_hvac = nothing
    existing_boiler = nothing
    boiler = nothing
    existing_chiller = nothing

    if haskey(d, "FlexibleHVAC")
        # TODO how to handle Matrix from JSON (to Dict) ?
        if flex_hvac_from_json
            flexible_hvac = FlexibleHVAC(d["FlexibleHVAC"])
        else
            flexible_hvac = FlexibleHVAC(; dictkeys_tosymbols(d["FlexibleHVAC"])...)
        end

        if sum(flexible_hvac.bau_hvac.existing_boiler_kw_thermal) ≈ 0.0 && 
            sum(flexible_hvac.bau_hvac.existing_chiller_kw_thermal) ≈ 0.0
            @warn "The FlexibleHVAC inputs indicate that no heating nor cooling is required. Not creating FlexibleHVAC model."
            flexible_hvac = nothing
        else
            # ExistingChiller and/or ExistingBoiler are added based on BAU_HVAC energy required to keep temperature within bounds
            if sum(flexible_hvac.bau_hvac.existing_boiler_kw_thermal) > 0
                boiler_inputs = Dict{Symbol, Any}()
                boiler_inputs[:max_heat_demand_kw] = maximum(flexible_hvac.bau_hvac.existing_boiler_kw_thermal)
                boiler_inputs[:time_steps_per_hour] = settings.time_steps_per_hour
                if haskey(d, "ExistingBoiler")
                    boiler_inputs = merge(boiler_inputs, dictkeys_tosymbols(d["ExistingBoiler"]))
                end
                existing_boiler = ExistingBoiler(; boiler_inputs...)

                if haskey(d, "Boiler")
                    boiler = Boiler(; dictkeys_tosymbols(d["Boiler"])...)
                end
                # TODO increase max_thermal_factor_on_peak_load to allow more heating flexibility?
            elseif haskey(d, "Boiler")
                @warn("Not creating Boiler because there is no heating load.") 
            end

            if sum(flexible_hvac.bau_hvac.existing_chiller_kw_thermal) > 0
                chiller_inputs = Dict{Symbol, Any}()
                chiller_inputs[:loads_kw_thermal] = flexible_hvac.bau_hvac.existing_chiller_kw_thermal                                 
                if haskey(d, "ExistingChiller")
                    if !haskey(d["ExistingChiller"], "cop")
                        d["ExistingChiller"]["cop"] = get_existing_chiller_default_cop(; existing_chiller_max_thermal_factor_on_peak_load=1.25, 
                                                                                        loads_kw=nothing, 
                                                                                        loads_kw_thermal=chiller_inputs[:loads_kw_thermal])
                    end 
                    chiller_inputs = merge(chiller_inputs, dictkeys_tosymbols(d["ExistingChiller"]))
                else
                    chiller_inputs[:cop] = get_existing_chiller_default_cop(; existing_chiller_max_thermal_factor_on_peak_load=1.25, 
                                                                                loads_kw=nothing, 
                                                                                loads_kw_thermal=chiller_inputs[:loads_kw_thermal])
                end              
                existing_chiller = ExistingChiller(; chiller_inputs...)
            end

            if haskey(d, "SpaceHeatingLoad")
                @warn "Not using SpaceHeatingLoad because FlexibleHVAC was provided."
            end

            if haskey(d, "DomesticHotWaterLoad")
                @warn "Not using DomesticHotWaterLoad because FlexibleHVAC was provided."
            end

            if haskey(d, "CoolingLoad")
                @warn "Not using CoolingLoad because FlexibleHVAC was provided."
            end
        end
    end

    if max_heat_demand_kw > 0 && !haskey(d, "FlexibleHVAC")  # create ExistingBoiler
        boiler_inputs = Dict{Symbol, Any}()
        boiler_inputs[:max_heat_demand_kw] = max_heat_demand_kw
        boiler_inputs[:time_steps_per_hour] = settings.time_steps_per_hour
        if haskey(d, "ExistingBoiler")
            boiler_inputs = merge(boiler_inputs, dictkeys_tosymbols(d["ExistingBoiler"]))
        end
        existing_boiler = ExistingBoiler(; boiler_inputs...)
    end

    if haskey(d, "Boiler")
        if max_heat_demand_kw > 0 && !haskey(d, "FlexibleHVAC")
            boiler = Boiler(; dictkeys_tosymbols(d["Boiler"])...)
        end
        if !(max_heat_demand_kw > 0) && !haskey(d, "FlexibleHVAC")
            @warn("Not creating Boiler because there is no heating load.")
        end
    end


    chp = nothing
    chp_prime_mover = nothing
    if haskey(d, "CHP")
        if !isnothing(existing_boiler)
            total_fuel_heating_load_mmbtu_per_hour = (space_heating_load.loads_kw + dhw_load.loads_kw) / existing_boiler.efficiency / KWH_PER_MMBTU
            avg_boiler_fuel_load_mmbtu_per_hour = sum(total_fuel_heating_load_mmbtu_per_hour) / length(total_fuel_heating_load_mmbtu_per_hour)
            chp = CHP(d["CHP"]; 
                    avg_boiler_fuel_load_mmbtu_per_hour = avg_boiler_fuel_load_mmbtu_per_hour,
                    existing_boiler = existing_boiler)
        else # Only if modeling CHP without heating_load and existing_boiler (for electric-only CHP)
            chp = CHP(d["CHP"])
        end
        chp_prime_mover = chp.prime_mover
    end

    max_cooling_demand_kw = 0
    if haskey(d, "CoolingLoad") && !haskey(d, "FlexibleHVAC")
        d["CoolingLoad"] = convert(Dict{String, Any}, d["CoolingLoad"])
        # Note, if thermal_loads_ton or one of the "...fraction(s)_of_electric_load" inputs is used for CoolingLoad, doe_reference_name is ignored 
        add_doe_reference_names_from_elec_to_thermal_loads(d["ElectricLoad"], d["CoolingLoad"])
        d["CoolingLoad"]["site_electric_load_profile"] = electric_load.loads_kw
        # Pass ExistingChiller inputs which are used in CoolingLoad processing, if they exist
        ec_empty = ExistingChiller(; loads_kw_thermal=zeros(8760*settings.time_steps_per_hour))
        if !haskey(d, "ExistingChiller")
            d["CoolingLoad"]["existing_chiller_max_thermal_factor_on_peak_load"] = ec_empty.max_thermal_factor_on_peak_load
        else
            if haskey(d["ExistingChiller"], "cop")
                d["CoolingLoad"]["existing_chiller_cop"] = d["ExistingChiller"]["cop"]
            end
            if haskey(d["ExistingChiller"], "max_thermal_factor_on_peak_load")
                d["CoolingLoad"]["existing_chiller_max_thermal_factor_on_peak_load"] = d["ExistingChiller"]["max_thermal_factor_on_peak_load"]
            else
                d["CoolingLoad"]["existing_chiller_max_thermal_factor_on_peak_load"] = ec_empty.max_thermal_factor_on_peak_load
            end
        end
        cooling_load = CoolingLoad(; dictkeys_tosymbols(d["CoolingLoad"])...,
                                    latitude=site.latitude, longitude=site.longitude, 
                                    time_steps_per_hour=settings.time_steps_per_hour
                                    )
        max_cooling_demand_kw = maximum(cooling_load.loads_kw_thermal)
    
        # Check if cooling electric load is greater than total electric load in any hour, and throw error if true with the violating time time_steps
        cooling_elec = cooling_load.loads_kw_thermal / cooling_load.existing_chiller_cop
        cooling_elec_too_high_timesteps = findall(cooling_elec .> electric_load.loads_kw)
        if length(cooling_elec_too_high_timesteps) > 0
            cooling_elec_too_high_kw = cooling_elec[cooling_elec_too_high_timesteps]
            total_elec_when_cooling_elec_too_high = electric_load.loads_kw[cooling_elec_too_high_timesteps]
            error("Cooling electric consumption cannot be more than the total electric load at any time step. At time steps 
                $cooling_elec_too_high_timesteps the cooling electric consumption is $cooling_elec_too_high_kw (kW) and
                the total electric load is $total_elec_when_cooling_elec_too_high (kW). Note you may consider adjusting 
                cooling load input versus the total electric load if you provided inputs in units of cooling tons, or 
                check the electric chiller COP input value.")
        end
    else
        cooling_load = CoolingLoad(; 
            thermal_loads_ton=zeros(8760*settings.time_steps_per_hour),
            time_steps_per_hour=settings.time_steps_per_hour
        )
    end

    absorption_chiller = nothing
    if max_cooling_demand_kw > 0 && !haskey(d, "FlexibleHVAC")  # create ExistingChiller
        chiller_inputs = Dict{Symbol, Any}()
        chiller_inputs[:loads_kw_thermal] = cooling_load.loads_kw_thermal
        if haskey(d, "ExistingChiller")
            if !haskey(d["ExistingChiller"], "cop")
                d["ExistingChiller"]["cop"] = cooling_load.existing_chiller_cop
            end
            chiller_inputs = merge(chiller_inputs, dictkeys_tosymbols(d["ExistingChiller"]))
        else
            chiller_inputs[:cop] = cooling_load.existing_chiller_cop
        end
        existing_chiller = ExistingChiller(; chiller_inputs...)

        if haskey(d, "AbsorptionChiller")
            absorption_chiller = AbsorptionChiller(d["AbsorptionChiller"]; 
                                                    existing_boiler = existing_boiler,
                                                    chp_prime_mover = chp_prime_mover,
                                                    cooling_load = cooling_load)
        end
    end

    # GHP
    ghp_option_list = []
    heating_thermal_load_reduction_with_ghp_kw = zeros(8760 * settings.time_steps_per_hour)
    cooling_thermal_load_reduction_with_ghp_kw = zeros(8760 * settings.time_steps_per_hour)
    eval_ghp = false
    get_ghpghx_from_input = false    
    if haskey(d, "GHP") && haskey(d["GHP"],"building_sqft")
        eval_ghp = true
        if haskey(d["GHP"], "ghpghx_responses") && !isempty(d["GHP"]["ghpghx_responses"])
            get_ghpghx_from_input = true
        end        
    elseif haskey(d, "GHP") && !haskey(d["GHP"],"building_sqft")
        error("If evaluating GHP you must enter a building_sqft")
    end
    # Modify Heating and Cooling loads for GHP retrofit to account for HVAC VAV efficiency gains
    if eval_ghp
        # Assign efficiency_thermal_factors if not specified (and if applicable to building type and climate zone)
        for factor in [("space_heating_efficiency_thermal_factor", "heating"), ("cooling_efficiency_thermal_factor", "cooling")]
            if isnan(d["GHP"][factor[1]])
                assign_thermal_factor!(d, factor[2])
            end
        end
        heating_thermal_load_reduction_with_ghp_kw = space_heating_load.loads_kw * (1.0 - d["GHP"]["space_heating_efficiency_thermal_factor"])
        cooling_thermal_load_reduction_with_ghp_kw = cooling_load.loads_kw_thermal * (1.0 - d["GHP"]["cooling_efficiency_thermal_factor"])
    end
    # Call GhpGhx.jl module if only ghpghx_inputs is given, otherwise use ghpghx_responses
    if eval_ghp && !(get_ghpghx_from_input)
        if d["GHP"]["ghpghx_inputs"] in [nothing, []]
            number_of_ghpghx = 1
            d["GHP"]["ghpghx_inputs"] = [Dict()]
        else
            number_of_ghpghx = length(d["GHP"]["ghpghx_inputs"])
        end
        # Call PVWatts for hourly dry-bulb outdoor air temperature
        ambient_temperature_f = []
        if !haskey(d["GHP"]["ghpghx_inputs"][1], "ambient_temperature_f") || isempty(d["GHP"]["ghpghx_inputs"][1]["ambient_temperature_f"])
            url = string("https://developer.nrel.gov/api/pvwatts/v6.json", "?api_key=", nrel_developer_key,
                    "&lat=", d["Site"]["latitude"] , "&lon=", d["Site"]["longitude"], "&tilt=", d["Site"]["latitude"],
                    "&system_capacity=1", "&azimuth=", 180, "&module_type=", 0,
                    "&array_type=", 0, "&losses=", 0.14, "&dc_ac_ratio=", 1.1,
                    "&gcr=", 0.4, "&inv_eff=", 99, "&timeframe=", "hourly", "&dataset=nsrdb",
                    "&radius=", 100)
            try
                @info "Querying PVWatts for ambient temperature"
                r = HTTP.get(url)
                response = JSON.parse(String(r.body))
                if r.status != 200
                    error("Bad response from PVWatts: $(response["errors"])")
                end
                @info "PVWatts success."
                temp_c = get(response["outputs"], "tamb", [])
                if length(temp_c) != 8760 || isempty(temp_c)
                    @error "PVWatts did not return a valid temperature profile. Got $temp_c"
                end
                ambient_temperature_f = temp_c * 1.8 .+ 32.0
            catch e
                @error "Error occurred when calling PVWatts: $e"
            end
        end
        
        for i in 1:number_of_ghpghx
            ghpghx_inputs = d["GHP"]["ghpghx_inputs"][i]
            d["GHP"]["ghpghx_inputs"][i]["ambient_temperature_f"] = ambient_temperature_f
            # Only SpaceHeating portion of Heating Load gets served by GHP, unless allowed by can_serve_dhw
            if get(ghpghx_inputs, "heating_thermal_load_mmbtu_per_hr", []) in [nothing, []]
                if d["GHP"]["can_serve_dhw"]
                    ghpghx_inputs["heating_thermal_load_mmbtu_per_hr"] = (space_heating_load.loads_kw + dhw_load.loads_kw - heating_thermal_load_reduction_with_ghp_kw)  / KWH_PER_MMBTU
                else
                    ghpghx_inputs["heating_thermal_load_mmbtu_per_hr"] = (space_heating_load.loads_kw - heating_thermal_load_reduction_with_ghp_kw) / KWH_PER_MMBTU
                end
            end
            if get(ghpghx_inputs, "cooling_thermal_load_ton", []) in [nothing, []]
                ghpghx_inputs["cooling_thermal_load_ton"] = (cooling_load.loads_kw_thermal - cooling_thermal_load_reduction_with_ghp_kw)  / KWH_THERMAL_PER_TONHOUR
            end
            # This code call GhpGhx.jl module functions and is only available if we load in the GhpGhx package
            try            
                # Update ground thermal conductivity based on climate zone if not user-input
                if isnothing(get(ghpghx_inputs, "ground_thermal_conductivity_btu_per_hr_ft_f", nothing))
                    k_by_zone = deepcopy(GhpGhx.ground_k_by_climate_zone)
                    nearest_city, climate_zone = find_ashrae_zone_city(d["Site"]["latitude"], d["Site"]["longitude"]; get_zone=true)
                    ghpghx_inputs["ground_thermal_conductivity_btu_per_hr_ft_f"] = k_by_zone[climate_zone]
                end
                # Call GhpGhx.jl to size GHP and GHX
                @info "Starting GhpGhx.jl" #with timeout of $(timeout) seconds..."
                results, inputs_params = GhpGhx.ghp_model(ghpghx_inputs)
                # Create a dictionary of the results data needed for REopt
                ghpghx_results = GhpGhx.get_results_for_reopt(results, inputs_params)
                ghpghx_response = Dict([("inputs", ghpghx_inputs), ("outputs", ghpghx_results)])
                @info "GhpGhx.jl model solved" #with status $(results["status"])."
                ghp_inputs_removed_ghpghx_inputs = deepcopy(d["GHP"])
                pop!(ghp_inputs_removed_ghpghx_inputs, "ghpghx_inputs")                
                append!(ghp_option_list, [GHP(ghpghx_response, ghp_inputs_removed_ghpghx_inputs)])
                # Print out ghpghx_response for loading into a future run without running GhpGhx.jl again
                open("scenarios/ghpghx_response.json","w") do f
                    JSON.print(f, ghpghx_response)
                end
            catch
                error("The GhpGhx package was not added (add https://github.com/NREL/GhpGhx.jl) or 
                    loaded (using GhpGhx) to the active Julia environment")
            end                
        end
    # If ghpghx_responses is included in inputs, do NOT run GhpGhx.jl model and use already-run ghpghx result as input to REopt
    elseif eval_ghp && get_ghpghx_from_input
        ghp_inputs_removed_ghpghx_responses = deepcopy(d["GHP"])
        pop!(ghp_inputs_removed_ghpghx_responses, "ghpghx_responses")
        if haskey(d["GHP"], "ghpghx_inputs")    
            pop!(ghp_inputs_removed_ghpghx_responses, "ghpghx_inputs")
        end
        for ghpghx_response in get(d["GHP"], "ghpghx_responses", [])
            append!(ghp_option_list, [GHP(ghpghx_response, ghp_inputs_removed_ghpghx_responses)])
        end
    end

    steam_turbine = nothing
    if haskey(d, "SteamTurbine") && d["SteamTurbine"]["max_kw"] > 0.0
        if !isnothing(existing_boiler)
            total_fuel_heating_load_mmbtu_per_hour = (space_heating_load.loads_kw + dhw_load.loads_kw) / existing_boiler.efficiency / KWH_PER_MMBTU
            avg_boiler_fuel_load_mmbtu_per_hour = sum(total_fuel_heating_load_mmbtu_per_hour) / length(total_fuel_heating_load_mmbtu_per_hour)
            steam_turbine = SteamTurbine(d["SteamTurbine"];  
                                        avg_boiler_fuel_load_mmbtu_per_hour = avg_boiler_fuel_load_mmbtu_per_hour)
        else
            steam_turbine = SteamTurbine(d["SteamTurbine"])
        end
    end

    return Scenario(
        settings,
        site, 
        pvs, 
        wind,
        storage,
        electric_tariff, 
        electric_load, 
        electric_utility, 
        financial,
        generator,
        dhw_load,
        space_heating_load,
        cooling_load,
        existing_boiler,
        boiler,
        chp,
        flexible_hvac,
        existing_chiller,
        absorption_chiller,
        ghp_option_list,
        heating_thermal_load_reduction_with_ghp_kw,
        cooling_thermal_load_reduction_with_ghp_kw,
        steam_turbine
    )
end


"""
    Scenario(fp::String)

Consruct Scenario from filepath `fp` to JSON with keys aligned with the `Scenario(d::Dict)` method.
"""
function Scenario(fp::String)
    Scenario(JSON.parsefile(fp); flex_hvac_from_json=true)
end


function add_doe_reference_names_from_elec_to_thermal_loads(elec::Dict, thermal::Dict)
    string_keys = [
        "doe_reference_name",
        "blended_doe_reference_names",
        "blended_doe_reference_percents",
    ]
    for k in string_keys
        if k in keys(elec) 
            if !(k in keys(thermal)) || isempty(thermal[k])
                thermal[k] = elec[k]
            end
        end
    end
end

