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
"""
    Techs(p::REoptInputs, s::BAUScenario)

Create a `Techs` struct for the BAUInputs
"""
function Techs(p::REoptInputs, s::BAUScenario)
    pvtechs = String[pv.name for pv in s.pvs]

    all_techs = copy(pvtechs)
    elec = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    techs_no_curtail = String[]
    segmented_techs = String[]
    gentechs = String[]
    pbi_techs = String[]
    heating_techs = String[]
    boiler_techs = String[]

    if p.s.generator.existing_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
        push!(elec, "Generator")
    end

    if p.s.existing_boiler.max_kw > 0
        push!(all_techs, "ExistingBoiler")
        push!(heating_techs, "ExistingBoiler")
        push!(boiler_techs, "ExistingBoiler")
    end

    fuel_burning_techs = union(gentechs, boiler_techs)
    thermal_techs = union(heating_techs, boiler_techs)

    Techs(
        all_techs,
        elec,
        pvtechs,
        gentechs,
        pbi_techs,
        techs_no_curtail,
        techs_no_turndown,
        segmented_techs,
        heating_techs,
        boiler_techs,
        fuel_burning_techs,
        thermal_techs
    )
end


"""
    Techs(s::Scenario) 

Create a `Techs` struct for the REoptInputs.
"""
function Techs(s::Scenario)
    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        error("PV names must be unique, got $(pvtechs)")
    end

    all_techs = copy(pvtechs)
    elec = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    gentechs = String[]
    pbi_techs = String[]
    techs_no_curtail = String[]
    segmented_techs = String[]
    heating_techs = String[]
    boiler_techs = String[]
    if s.wind.max_kw > 0
        push!(all_techs, "Wind")
        push!(elec, "Wind")
    end
    if s.generator.max_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
        push!(elec, "Generator")
    end

    if s.existing_boiler.max_kw > 0
        push!(all_techs, "ExistingBoiler")
        push!(heating_techs, "ExistingBoiler")
        push!(boiler_techs, "ExistingBoiler")
    end

    if "Wind" in all_techs
        append!(techs_no_turndown, ["Wind"])
    end

    thermal_techs = union(heating_techs, boiler_techs)
    fuel_burning_techs = union(gentechs, boiler_techs)

    Techs(
        all_techs,
        elec,
        pvtechs,
        gentechs,
        pbi_techs,
        techs_no_curtail,
        techs_no_turndown,
        segmented_techs,
        heating_techs,
        boiler_techs,
        fuel_burning_techs,
        thermal_techs
    )
end


"""
    Techs(s::MPCScenario) 

Create a `Techs` struct for the MPCInputs
"""
function Techs(s::MPCScenario)
    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        error("PV names must be unique, got $(pvtechs)")
    end

    all_techs = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    gentechs = String[]
    if s.generator.size_kw > 0
        push!(all_techs, "Generator")
        push!(gentechs, "Generator")
    end

    Techs(
        all_techs,
        all_techs,
        pvtechs,
        gentechs,
        String[],
        String[],
        techs_no_turndown,
        String[],
        String[],
        String[],
        String[],
        String[]
    )
end