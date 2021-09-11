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
    OutageOutputs

Struct for storing `bau_critical_load_met` and `bau_critical_load_met_time_steps`.
This struct is attached to the BAUScenario s.t. the outputs can be passed back to the user.
It is mutable s.t. that it can be adjusted in BAUInputs.
"""
Base.@kwdef mutable struct OutageOutputs
    bau_critical_load_met::Bool = true
    bau_critical_load_met_time_steps::Int = 0
end


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
    outage_outputs::OutageOutputs
end


function set_min_max_kw_to_existing(tech::AbstractTech)
    techdict = Dict(fn => getfield(tech, fn) for fn in fieldnames(typeof(tech)))
    techdict[:min_kw] = techdict[:existing_kw]
    techdict[:max_kw] = techdict[:existing_kw]
    eval(Meta.parse(string(typeof(tech)) * "(; $techdict...)"))
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
        if pv.existing_kw > 0
            push!(pvs, set_min_max_kw_to_existing(pv))
        end
    end

    # set Generator.max_kw to existing_kw
    generator = set_min_max_kw_to_existing(s.generator)

    # no existing wind
    wind = Wind(; max_kw=0)

    # no existing storage
    storage = Storage(Dict(:elec => Dict(:max_kw => 0)), s.financial)
    
    t0, tf = s.electric_utility.outage_start_time_step, s.electric_utility.outage_end_time_step
    #=
    When a deterministic grid outage is modeled we must adjust the BAU critical load profile to keep the problem 
    feasible and to get the same ElectricTariff costs in both the optimal and BAU scenarios
    (because the BAU scenario may not have enough existing capacity to meet the critical load and because during an
    outage no grid costs are incurred).
    In the simplest case we set the BAU critical_loads_kw to zero during the outage. 
    However, if the BAU scenario has existing Generator and/or PV we calculate how many time steps the critical load can 
    be met and make the critical load non-zero for those time steps in order to show the most realistic dispatch results.
    This calculation requires the PV prod_factor_series_kw and so it is done in BAUInputs.
    =#
    elec_load = deepcopy(s.electric_load)
    if tf > t0 && t0 > 0
        elec_load.critical_loads_kw[t0:tf] = zeros(tf-t0+1)  # set crit load to zero 
    end
    outage_outputs = OutageOutputs()

    return BAUScenario(
        s.settings,
        s.site, 
        pvs, 
        wind,
        storage, 
        s.electric_tariff, 
        elec_load, 
        s.electric_utility, 
        s.financial,
        generator,
        outage_outputs
    )
end