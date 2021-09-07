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
struct BAUScenario <: AbstractScenario
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
end


function set_max_kw_to_existing(tech::AbstractTech)
    techdict = Dict(fn => getfield(x, fn) for fn in fieldnames(typeof(x)))
    techdict[:max_kw] = techdict[:existing_kw]
    eval(Meta.parse(string(typeof(tech)) * "(; techdict...)"))
end


"""
    BAUScenario(s::Scenario)

Constructor for BAUScenario (BAU = Business As Usual) struct.
- sets the PV and Generator max_kw values to the existing_kw values
- sets wind and storage max_kw values to zero
"""
function BAUScenario(s::Scenario)

    # set all PV.max_kw to existing_kw
    pvs = PV[]
    for pv in s.pvs
        push!(pvs, set_max_kw_to_existing(pv))
    end

    # set Generator.max_kw to existing_kw
    generator = set_max_kw_to_existing(s.generator)

    # no existing wind
    wind = Wind(; max_kw=0)

    # no existing storage
    storage = Storage(Dict(:elec => Dict(:max_kw => 0)), s.financial)

    return BAUScenario(
        s.settings,
        s.site, 
        pvs, 
        wind,
        storage, 
        s.electric_tariff, 
        s.electric_load, 
        s.electric_utility, 
        s.financial,
        generator
    )
end
