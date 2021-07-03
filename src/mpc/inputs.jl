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

struct MPCInputs <: AbstractInputs
    techs::Array{String, 1}
    pvtechs::Array{String, 1}
    gentechs::Array{String,1}
    elec_techs::Array{String, 1}
    techs_no_turndown::Array{String, 1}
    existing_sizes::DenseAxisArray{Float64, 1}  # (techs)
    elec_load::MPCElectricLoad
    time_steps::UnitRange
    time_steps_with_grid::Array{Int, 1}
    time_steps_without_grid::Array{Int, 1}
    hours_per_timestep::Float64
    months::UnitRange
    production_factor::DenseAxisArray{Float64, 2}  # (techs, time_steps)
    levelization_factor::DenseAxisArray{Float64, 1}  # (techs)
    VoLL::Array{R, 1} where R<:Real #default set to 1 US dollar per kwh
    pwf_e::Float64
    pwf_om::Float64
    two_party_factor::Float64
    etariff::MPCElectricTariff
    ratchets::UnitRange
    techs_by_exportbin::DenseAxisArray{Array{String,1}}  # indexed on [:NEM, :WHL]
    storage::MPCStorage
    generator::MPCGenerator
    elecutil::ElectricUtility
    max_grid_export_kwh::Float64
    export_bins_by_tech::Dict{String, Array{Symbol, 1}}
end


function MPCInputs(fp::String)
    s = MPCScenario(JSON.parsefile(fp))
    MPCInputs(s)
end


function MPCInputs(s::MPCScenario)

    time_steps = 1:length(s.electric_load.loads_kw)
    hours_per_timestep = 1 / s.settings.time_steps_per_hour
    techs, pvtechs, gentechs, production_factor, existing_sizes = setup_tech_inputs(s)
    elec_techs = techs  # only modeling electric loads/techs so far
    techs_no_turndown = pvtechs
    max_grid_export_kwh = sum(s.electric_load.loads_kw)
    months = 1:length(s.electric_tariff.monthly_demand_rates)

    techs_by_exportbin = DenseAxisArray([ techs, techs, techs], s.electric_tariff.export_bins)
    # TODO account for which techs have access to export bins (when we add more techs than PV)

    levelization_factor = DenseAxisArray(repeat([1.0], length(techs)), techs)
    pwf_e = 1.0
    pwf_om = 1.0
    two_party_factor = 1.0

    time_steps_with_grid, time_steps_without_grid, = setup_electric_utility_inputs(s)

    export_bins_by_tech = Dict{String, Array{Symbol, 1}}()
    for t in elec_techs
        export_bins_by_tech[t] = s.electric_tariff.export_bins
    end
    # TODO implement export bins by tech (rather than assuming that all techs share the export_bins)
 
    MPCInputs(
        techs,
        pvtechs,
        gentechs,
        elec_techs,
        techs_no_turndown,
        existing_sizes,
        s.electric_load,
        time_steps,
        time_steps_with_grid,
        time_steps_without_grid,
        hours_per_timestep,
        months,
        production_factor,
        levelization_factor,  # TODO need this?
        typeof(s.financial.VoLL) <: Array{<:Real, 1} ? s.financial.VoLL : fill(s.financial.VoLL, length(time_steps)),
        pwf_e,
        pwf_om,
        two_party_factor,
        # maxsize_pv_locations,
        s.electric_tariff,
        1:length(s.electric_tariff.tou_demand_ratchet_timesteps),  # ratchets
        techs_by_exportbin,
        s.storage,
        s.generator,
        s.electric_utility,
        max_grid_export_kwh,
        export_bins_by_tech
        # s.site.min_resil_timesteps,
        # s.site.mg_tech_sizes_equal_grid_sizes,
        # s.site.node
    )
end


function setup_tech_inputs(s::MPCScenario)

    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        error("PV names must be unique, got $(pvtechs)")
    end

    techs = copy(pvtechs)
    gentechs = String[]
    if s.generator.size_kw > 0
        push!(techs, "Generator")
        push!(gentechs, "Generator")
    end

    time_steps = 1:length(s.electric_load.loads_kw)

    # REoptInputs indexed on techs:
    existing_sizes = DenseAxisArray{Float64}(undef, techs)
    production_factor = DenseAxisArray{Float64}(undef, techs, time_steps)

    if !isempty(pvtechs)
        setup_pv_inputs(s, existing_sizes, production_factor)
    end

    if "Generator" in techs
        setup_gen_inputs(s, existing_sizes, production_factor)
    end

    return techs, pvtechs, gentechs, production_factor, existing_sizes
end


function setup_pv_inputs(s::MPCScenario, existing_sizes, production_factor)
    for pv in s.pvs
        production_factor[pv.name, :] = pv.prod_factor_series_kw
        existing_sizes[pv.name] = pv.size_kw
    end
    return nothing
end


function setup_gen_inputs(s::MPCScenario, existing_sizes, production_factor)
    existing_sizes["Generator"] = s.generator.size_kw
    production_factor["Generator", :] = ones(length(s.electric_load.loads_kw))
    return nothing
end
