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
    chp::Union{CHP, Nothing}  # use nothing for more items when they are not modeled?
    flexible_hvac::Union{FlexibleHVAC, Nothing}
    existing_chiller::Union{ExistingChiller, Nothing}
    absorption_chiller::Union{AbsorptionChiller, Nothing}
    ghp_option_list::Array{Union{GHP, Nothing}, 1}  # List of GHP objects (often just 1 element, but can be more)
    heating_thermal_load_reduction_with_ghp_kw::Union{Vector{Float64}, Nothing}
    cooling_thermal_load_reduction_with_ghp_kw::Union{Vector{Float64}, Nothing}
end

"""
    Scenario(d::Dict; flex_hvac_from_json=false)

Constructor for Scenario struct, where `d` has upper-case keys:
- [Site](@ref) (required)
- [ElectricTariff](@ref) (required)
- [ElectricLoad](@ref) (required)
- [PV](@ref) (optional, can be Array)
- [Wind](@ref) (optional)
- [ElectricStorage](@ref) (optional)
- [ElectricUtility](@ref) (optional)
- [Financial](@ref) (optional)
- [Generator](@ref) (optional)
- [DomesticHotWaterLoad](@ref) (optional)
- [SpaceHeatingLoad](@ref) (optional)
- [ExistingBoiler](@ref) (optional)
- [CHP](@ref) (optional)
- FlexibleHVAC (optional)
- ExistingChiller (optional)
- AbsorptionChiller (optional)
- GHP (optional)

All values of `d` are expected to be `Dicts` except for `PV`, which can be either a `Dict` or `Dict[]`.

Set `flex_hvac_from_json=true` if `FlexibleHVAC` values were loaded in from JSON (necessary to 
handle conversion of Vector of Vectors from JSON to a Matrix in Julia).
"""
function Scenario(d::Dict; flex_hvac_from_json=false)
    if haskey(d, "Settings")
        settings = Settings(;dictkeys_tosymbols(d["Settings"])...)
    else
        settings = Settings()
    end
    
    site = Site(;dictkeys_tosymbols(d["Site"])...)
    
    pvs = PV[]
    if haskey(d, "PV")
        if typeof(d["PV"]) <: AbstractArray
            for (i, pv) in enumerate(d["PV"])
                check_pv_tilt!(pv, site)
                if !(haskey(pv, "name"))
                    pv["name"] = string("PV", i)
                end
                push!(pvs, PV(;dictkeys_tosymbols(pv)...))
            end
        elseif typeof(d["PV"]) <: AbstractDict
            check_pv_tilt!(d["PV"], site)
            push!(pvs, PV(;dictkeys_tosymbols(d["PV"])...))
        else
            error("PV input must be Dict or Dict[].")
        end
    end

    if haskey(d, "Financial")
        financial = Financial(; dictkeys_tosymbols(d["Financial"])...)
    else
        financial = Financial()
    end

    if haskey(d, "ElectricUtility")
        electric_utility = ElectricUtility(; dictkeys_tosymbols(d["ElectricUtility"])...)
    else
        electric_utility = ElectricUtility()
    end

    storage_structs = Dict{String, AbstractStorage}()
    if haskey(d,  "ElectricStorage")
        storage_dict = dictkeys_tosymbols(d["ElectricStorage"])
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
                                   time_steps_per_hour=settings.time_steps_per_hour
                                )

    electric_tariff = ElectricTariff(; dictkeys_tosymbols(d["ElectricTariff"])..., 
                                       year=electric_load.year,
                                       NEM=electric_utility.net_metering_limit_kw > 0, 
                                       time_steps_per_hour=settings.time_steps_per_hour
                                    )

    if haskey(d, "Wind")
        wind = Wind(; dictkeys_tosymbols(d["Wind"])..., 
                    average_elec_load=sum(electric_load.loads_kw) / length(electric_load.loads_kw))
    else
        wind = Wind(; max_kw=0)
    end

    if haskey(d, "Generator")
        generator = Generator(; dictkeys_tosymbols(d["Generator"])...)
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
                # TODO automatically add CHP or other heating techs?
                # TODO increase max_thermal_factor_on_peak_load to allow more heating flexibility?
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

    if max_heat_demand_kw > 0 && !haskey(d, "FlexibleHVAC")  # create ExistingBoler
        boiler_inputs = Dict{Symbol, Any}()
        boiler_inputs[:max_heat_demand_kw] = max_heat_demand_kw
        boiler_inputs[:time_steps_per_hour] = settings.time_steps_per_hour
        # If CHP is considered, prime_mover may inform the default boiler efficiency
        if haskey(d, "CHP") 
            if haskey(d["CHP"], "prime_mover")
                boiler_inputs[:chp_prime_mover] = d["CHP"]["prime_mover"]
            end
        end
        if haskey(d, "ExistingBoiler")
            boiler_inputs = merge(boiler_inputs, dictkeys_tosymbols(d["ExistingBoiler"]))
        end
        existing_boiler = ExistingBoiler(; boiler_inputs...)
    end

    chp = nothing
    if haskey(d, "CHP")
        chp = CHP(d["CHP"])
    end

    max_cooling_demand_kw = 0
    if haskey(d, "CoolingLoad") && !haskey(d, "FlexibleHVAC")
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
            chiller_inputs[:cop] = 1.0
        end
        existing_chiller = ExistingChiller(; chiller_inputs...)

        if haskey(d, "AbsorptionChiller")
            absorption_chiller = AbsorptionChiller(; dictkeys_tosymbols(d["AbsorptionChiller"])...)
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
        @error("If evaluating GHP you must enter a building_sqft")
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
            ghpghx_results = GhpGhx.get_GhpGhx_results_for_reopt(results, inputs_params)
            ghpghx_response = Dict([("inputs", ghpghx_inputs), ("outputs", ghpghx_results)])
            @info "GhpGhx.jl model solved" #with status $(results["status"])."
            append!(ghp_option_list, [GHP(ghpghx_response, d["GHP"])])
            # The API created a response with inputs and outputs (in make_response), but we currently only have outputs/results
            # open("ghpghx_response.json","w") do f
            #     JSON.print(f, ghpghx_response)
            # end
        end
    # If ghpghx_responses is included in inputs, do NOT run GhpGhx.jl model and use already-run ghpghx result as input to REopt
    elseif eval_ghp && get_ghpghx_from_input
        for ghpghx_response in get(d["GHP"], "ghpghx_responses", [])
            append!(ghp_option_list, [GHP(ghpghx_response, d["GHP"])])
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
        chp,
        flexible_hvac,
        existing_chiller,
        absorption_chiller,
        ghp_option_list,
        heating_thermal_load_reduction_with_ghp_kw,
        cooling_thermal_load_reduction_with_ghp_kw
    )
end


"""
    Scenario(fp::String)

Consruct Scenario from filepath `fp` to JSON with keys aligned with the `Scenario(d::Dict)` method.
"""
function Scenario(fp::String)
    Scenario(JSON.parsefile(fp); flex_hvac_from_json=true)
end


function check_pv_tilt!(pv::Dict, site::Site)
    if !(haskey(pv, "tilt"))
        pv["tilt"] = site.latitude
    end
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
