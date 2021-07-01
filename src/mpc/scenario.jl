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
struct MPCScenario <: AbstractScenario
    settings::Settings
    pvs::Array{MPCPV, 1}
    storage::MPCStorage
    electric_tariff::MPCElectricTariff
    electric_load::MPCElectricLoad
    electric_utility::ElectricUtility
    financial::MPCFinancial
    generator::MPCGenerator
end


"""
    MPCScenario(d::Dict)

Method for creating the MPCScenario struct:
    struct MPCScenario <: AbstractScenario
        settings::Settings
        pvs::Array{MPCPV, 1}
        storage::MPCStorage
        electric_tariff::MPCElectricTariff
        electric_load::MPCElectricLoad
        electric_utility::ElectricUtility
        financial::MPCFinancial
        generator::MPCGenerator
    end
The Dict `d` must have at a minimum the keys:
    - "ElectricLoad"
    - "ElectricTariff"
Other options include:
    - "PV", which can contain a Dict or Dict[]
    - "Storage"
    - "Generator"
    - "ElectricUtility"
    - "Settings"
    - "Financial"
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
            error("PV input must be Dict or Dict[].")
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

    if haskey(d, "Storage")
        # only modeling electrochemical storage so far
        storage_dict = Dict(dictkeys_tosymbols(d["Storage"]))
        storage = MPCStorage(storage_dict)
    else
        storage_dict = Dict(:size_kw => 0.0, :size_kwh => 0.0)
        storage = MPCStorage(storage_dict)
    end

    electric_load = MPCElectricLoad(; dictkeys_tosymbols(d["ElectricLoad"])...)

    electric_tariff = MPCElectricTariff(d["ElectricTariff"])

    if haskey(d, "Generator")
        generator = MPCGenerator(; dictkeys_tosymbols(d["Generator"])...)
    else
        generator = MPCGenerator(; size_kw=0)
    end

    return MPCScenario(
        settings,
        pvs, 
        storage, 
        electric_tariff, 
        electric_load, 
        electric_utility, 
        financial,
        generator
    )
end
