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
    existing_boiler::ExistingBoiler
end

"""
    Scenario(d::Dict)

Constructor for Scenario struct, where `d` has upper-case keys:
- Site (required)
- ElectricTariff (required)
- ElectricLoad (required)
- PV (optional, can be Array)
- Wind (optional)
- Storage (optional)
- ElectricUtility (optional)
- Financial (optional)
- Generator (optional)
- DomesticHotWaterLoad (optional)
- SpaceHeatingLoad (optional)
- ExistingBoiler (optional)

All values of `d` are expected to be `Dicts` except for `PV`, which can be either a `Dict` or `Dict[]`.
```
struct Scenario
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
    existing_boiler::ExistingBoiler
end
```
"""
function Scenario(d::Dict)
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

    if haskey(d, "Storage")
        # only modeling electrochemical storage so far
        storage_dict = Dict(:elec => dictkeys_tosymbols(d["Storage"]))
        storage = Storage(storage_dict, financial)
    else
        storage_dict = Dict(:elec => Dict(:max_kw => 0))
        storage = Storage(storage_dict, financial)
    end

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
    if haskey(d, "DomesticHotWaterLoad")
        add_doe_reference_names_from_elec_to_thermal_loads(d["ElectricLoad"], d["DomesticHotWaterLoad"])
        dhw_load = DomesticHotWaterLoad(; dictkeys_tosymbols(d["DomesticHotWaterLoad"])...,
                                          latitude=site.latitude, longitude=site.longitude, 
                                          time_steps_per_hour=settings.time_steps_per_hour
                                        )
        max_heat_demand_kw = maximum(dhw_load.loads_kw)
    else
        dhw_load = DomesticHotWaterLoad(; fuel_loads_mmbtu_per_hour=repeat([0.0], 8760))
    end
                                    
    if haskey(d, "SpaceHeatingLoad")
        add_doe_reference_names_from_elec_to_thermal_loads(d["ElectricLoad"], d["SpaceHeatingLoad"])
        space_heating_load = SpaceHeatingLoad(; dictkeys_tosymbols(d["SpaceHeatingLoad"])...,
                                                latitude=site.latitude, longitude=site.longitude, 
                                                time_steps_per_hour=settings.time_steps_per_hour
                                              )
        
        max_heat_demand_kw = maximum(space_heating_load.loads_kw .+ max_heat_demand_kw)
    else
        space_heating_load = SpaceHeatingLoad(; fuel_loads_mmbtu_per_hour=repeat([0.0], 8760))
    end

    if max_heat_demand_kw > 0
        vals = Dict{Symbol, Any}()
        vals[:max_heat_demand_kw] = max_heat_demand_kw
        vals[:time_steps_per_hour] = settings.time_steps_per_hour
        if haskey(d, "ExistingBoiler")
            vals = merge(vals, dictkeys_tosymbols(d["ExistingBoiler"]))
        end
        existing_boiler = ExistingBoiler(; vals...)
    else
        existing_boiler = ExistingBoiler(0.0, 0.0, Real[])
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
        existing_boiler
    )
end


"""
    Scenario(fp::String)

Consruct Scenario from filepath `fp` to JSON with keys aligned with the `Scenario(d::Dict)` method.
"""
function Scenario(fp::String)
    Scenario(JSON.parsefile(fp))
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
        if !(k in keys(thermal)) && k in keys(elec)
            thermal[k] = elec[k]
        end
    end
end