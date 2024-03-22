# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
struct MPCScenario <: AbstractScenario
    settings::Settings
    pvs::Array{MPCPV, 1}
    storage::Storage
    electric_tariff::MPCElectricTariff
    electric_load::MPCElectricLoad
    electric_utility::ElectricUtility
    financial::MPCFinancial
    generator::MPCGenerator
    electrolyzer::MPCElectrolyzer
    hydrogen_storage::MPCHydrogenStorage
    fuel_cell::MPCFuelCell
    cooling_load::MPCCoolingLoad
    process_heat_load::MPCProcessHeatLoad
    electric_heater::MPCElectricHeater
    flexible_hvac::Union{FlexibleHVAC, Nothing}
    limits::MPCLimits
    node::Int
end


"""
    MPCScenario(d::Dict)

Method for creating the MPCScenario struct:
```julia
    struct MPCScenario <: AbstractScenario
        settings::Settings
        pvs::Array{MPCPV, 1}
        storage::Storage
        electric_tariff::MPCElectricTariff
        electric_load::MPCElectricLoad
        electric_utility::ElectricUtility
        financial::MPCFinancial
        generator::MPCGenerator
        electrolyzer::MPCElectrolyzer
        hydrogen_storage::MPCHydrogenStorage
        fuel_cell::MPCFuelCell
        cooling_load::MPCCoolingLoad
        process_heat_load::MPCProcessHeatLoad
        electric_heater::MPCElectricHeater
        limits::MPCLimits
        node::Int
    end
```

The Dict `d` must have at a minimum the keys:
    - "ElectricLoad"
    - "ElectricTariff"

Other options include:
    - "PV", which can contain a Dict or Dict[]
    - "ElectricStorage"
    - "Generator"
    - "Electrolyzer"
    - "HydrogenStorage"
    - "FuelCell"
    - "ElectricUtility"
    - "Settings"
    - "Financial"
    - "Limits"
"""
function MPCScenario(d::Dict)
    if haskey(d, "Settings")
        settings = Settings(;dictkeys_tosymbols(d["Settings"])...)
    else
        settings = Settings()
    end
    
    pvs = MPCPV[]
    if haskey(d, "PV")
        if typeof(d["PV"]) <: AbstractArray
            for (i, pv) in enumerate(d["PV"])
                if !(haskey(pv, "name"))
                    pv["name"] = string("PV", i)
                end
                push!(pvs, MPCPV(;dictkeys_tosymbols(pv)...))
            end
        elseif typeof(d["PV"]) <: AbstractDict
            push!(pvs, MPCPV(;dictkeys_tosymbols(d["PV"])...))
        else
            throw(@error("PV input must be Dict or Dict[]."))
        end
    end

    if haskey(d, "Financial")
        financial = MPCFinancial(; dictkeys_tosymbols(d["Financial"])...)
    else
        financial = MPCFinancial()
    end

    if haskey(d, "ElectricUtility")
        electric_utility = ElectricUtility(; dictkeys_tosymbols(d["ElectricUtility"])...)
    else
        electric_utility = ElectricUtility()
    end

    if haskey(d, "ElectricStorage")
        # only modeling electrochemical storage so far
        storage_dict = Dict(dictkeys_tosymbols(d["ElectricStorage"]))
    else
        storage_dict = Dict(:size_kw => 0.0, :size_kwh => 0.0)
    end
    storage = Storage(Dict{String, AbstractStorage}("ElectricStorage" => MPCElectricStorage(; storage_dict...)))

    if haskey(d, "Electrolyzer")
        electrolyzer = MPCElectrolyzer(; dictkeys_tosymbols(d["Electrolyzer"])...)
    else
        electrolyzer = MPCElectrolyzer(; size_kw=0)
    end

    if haskey(d, "HydrogenStorage")
        hydrogen_storage = MPCHydrogenStorage(; dictkeys_tosymbols(d["HydrogenStorage"])...)
    else
        hydrogen_storage = MPCHydrogenStorage(; size_kg=0)
    end

    if haskey(d, "FuelCell")
        fuel_cell = MPCFuelCell(; dictkeys_tosymbols(d["FuelCell"])...)
    else
        fuel_cell = MPCFuelCell(; size_kw=0)
    end
    
    electric_load = MPCElectricLoad(; dictkeys_tosymbols(d["ElectricLoad"])...)

    electric_tariff = MPCElectricTariff(d["ElectricTariff"])

    if haskey(d, "Generator")
        generator = MPCGenerator(; dictkeys_tosymbols(d["Generator"])...)
    else
        generator = MPCGenerator(; size_kw=0)
    end

    if haskey(d, "ProcessHeatLoad")
        process_heat_load = MPCProcessHeatLoad(; dictkeys_tosymbols(d["ProcessHeatLoad"])...)
    else
        process_heat_load = MPCProcessHeatLoad()
    end

    if haskey(d, "ElectricHeater")
        electric_heater = MPCElectricHeater(; dictkeys_tosymbols(d["ElectricHeater"])...)
    else
        electric_heater = MPCElectricHeater(; size_mmbtu_per_hour=0)
    end

    flexible_hvac = nothing

    # Placeholder/dummy cooling load set to zeros
    cooling_load = MPCCoolingLoad(; loads_kw_thermal = zeros(length(electric_load.loads_kw)), cop=1.0)
    if haskey(d, "Limits")
        limits = MPCLimits(; dictkeys_tosymbols(d["Limits"])...)
    else
        limits = MPCLimits()
    end

    if haskey(d, "node")
        node = d["node"]
    else
        node = 1
    end

    return MPCScenario(
        settings,
        pvs, 
        storage, 
        electric_tariff, 
        electric_load, 
        electric_utility, 
        financial,
        generator,
        electrolyzer,
        hydrogen_storage,
        fuel_cell,
        cooling_load,
        process_heat_load,
        electric_heater,
        flexible_hvac,
        limits,
        node
    )
end
