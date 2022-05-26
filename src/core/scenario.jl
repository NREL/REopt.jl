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
    thermosyphon::Union{Thermosyphon, Nothing}
end

"""
    Scenario(d::Dict; flex_hvac_from_json=false)

Constructor for Scenario struct, where `d` has upper-case keys:
- [Site](@ref) (required)
- [ElectricTariff](@ref) (required when off_grid_flag is False)
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
- Thermosyphon (optional)

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

    # Check that only PV, electric storage, and generator are modeled for off-grid
    if settings.off_grid_flag
        offgrid_allowed_keys = ["PV", "ElectricStorage", "Generator", "Settings", "Site", "Financial", "ElectricLoad", "ElectricTariff", "ElectricUtility"]
        unallowed_keys = setdiff(keys(d), offgrid_allowed_keys) 
        if !isempty(unallowed_keys)
            throw(@error "Currently, only PV, ElectricStorage, and Generator can be modeled when off_grid_flag is true. Cannot model $unallowed_keys.")
        end
    end
    
    pvs = PV[]
    if haskey(d, "PV")
        if typeof(d["PV"]) <: AbstractArray
            for (i, pv) in enumerate(d["PV"])
                check_pv_tilt!(pv, site)
                if !(haskey(pv, "name"))
                    pv["name"] = string("PV", i)
                end
                push!(pvs, PV(;dictkeys_tosymbols(pv)..., off_grid_flag = settings.off_grid_flag))
            end
        elseif typeof(d["PV"]) <: AbstractDict
            check_pv_tilt!(d["PV"], site)
            push!(pvs, PV(;dictkeys_tosymbols(d["PV"])..., off_grid_flag = settings.off_grid_flag))
        else
            error("PV input must be Dict or Dict[].")
        end
    end

    if haskey(d, "Financial")
        financial = Financial(; dictkeys_tosymbols(d["Financial"])..., off_grid_flag = settings.off_grid_flag )
    else
        financial = Financial(; off_grid_flag = settings.off_grid_flag)
    end

    if haskey(d, "ElectricUtility") && !(settings.off_grid_flag)
        electric_utility = ElectricUtility(; dictkeys_tosymbols(d["ElectricUtility"])...)
    elseif !(settings.off_grid_flag)
        electric_utility = ElectricUtility()
    elseif settings.off_grid_flag 
        if haskey(d, "ElectricUtility")
            @warn "ElectricUtility inputs are not applicable when off_grid_flag is true and any ElectricUtility inputs will be ignored. For off-grid scenarios, a year-long outage will always be modeled."
        end
        electric_utility = ElectricUtility(; outage_start_time_step = 1, outage_end_time_step = settings.time_steps_per_hour * 8760) 
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
        wind = Wind(; dictkeys_tosymbols(d["Wind"])..., 
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

    if haskey(d, "Thermosyphon")
        thermosyphon = Thermosyphon(; dictkeys_tosymbols(d["Thermosyphon"])..., latitude=site.latitude, longitude=site.longitude)
    else
        thermosyphon = nothing
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
        thermosyphon
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
