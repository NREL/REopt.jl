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
abstract type AbstractTech end
abstract type AbstractStorage end
abstract type AbstractFuelBurningTech <: AbstractTech end
abstract type AbstractGenerator <: AbstractFuelBurningTech end
abstract type AbstractScenario end
abstract type AbstractInputs end
abstract type AbstractThermalTech <: AbstractGenerator end
abstract type AbstractCHP <: AbstractFuelBurningTech end
abstract type AbstractThermalStorage <: AbstractStorage end
abstract type AbstractElectricStorage <: AbstractStorage end
abstract type AbstractHydrogenStorage <: AbstractStorage end
abstract type AbstractThermalStorageDefaults end
abstract type AbstractGHP <: AbstractTech end
abstract type AbstractSteamTurbine <: AbstractTech end
abstract type AbstractElectrolyzer <: AbstractTech end
abstract type AbstractCompressor <: AbstractTech end
abstract type AbstractFuelCell <: AbstractTech end


"""
    Techs

`Techs` contains the index sets that are used to define the model constraints and decision variables.

```julia
mutable struct Techs
    all::Vector{String}
    elec::Vector{String}
    pv::Vector{String}
    gen::Vector{String}
    pbi::Vector{String}
    no_curtail::Vector{String}
    no_turndown::Vector{String}
    segmented::Vector{String}
    heating::Vector{String}
    cooling::Vector{String}
    boiler::Vector{String}
    fuel_burning::Vector{String}
    thermal::Vector{String}
    chp::Vector{String}
    requiring_oper_res::Vector{String}
    providing_oper_res::Vector{String}
    electric_chiller::Vector{String}
    absorption_chiller::Vector{String}
    steam_turbine::Vector{String}
    can_supply_steam_turbine::Vector{String}    
end
```
"""
mutable struct Techs
    all::Vector{String}
    elec::Vector{String}
    pv::Vector{String}
    gen::Vector{String}
    electrolyzer::Vector{String}
    compressor::Vector{String}
    fuel_cell::Vector{String}
    pbi::Vector{String}
    no_curtail::Vector{String}
    no_turndown::Vector{String}
    segmented::Vector{String}
    heating::Vector{String}
    cooling::Vector{String}
    boiler::Vector{String}
    fuel_burning::Vector{String}
    thermal::Vector{String}
    chp::Vector{String}
    requiring_oper_res::Vector{String}
    providing_oper_res::Vector{String}
    electric_chiller::Vector{String}
    absorption_chiller::Vector{String}
    steam_turbine::Vector{String}
    can_supply_steam_turbine::Vector{String}
end
