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

Create a REoptInputs for the Business As Usual scenario.
"""
function BAUInputs(p::REoptInputs)

    bau_scenario = BAUScenario(p.s)
    pvtechs = String[pv.name for pv in bau_scenario.pvs]

    techs = copy(pvtechs)
    techs_no_turndown = copy(pvtechs)
    gentechs = String[]
    pbi_techs = String[]

    if p.s.generator.existing_kw > 0
        push!(techs, "Generator")
        push!(gentechs, "Generator")
    end

    elec_techs = copy(techs)  # only modeling electric loads/techs so far

    # REoptInputs indexed on techs:
    max_sizes = Dict(t => 0.0 for t in techs)
    min_sizes = Dict(t => 0.0 for t in techs)
    existing_sizes = Dict(t => 0.0 for t in techs)
    cap_cost_slope = Dict{String, Any}()
    om_cost_per_kw = Dict(t => 0.0 for t in techs)
    production_factor = DenseAxisArray{Float64}(undef, techs, p.time_steps)

    # export related inputs
    techs_by_exportbin = Dict(k => [] for k in p.s.electric_tariff.export_bins)
    export_bins_by_tech = Dict{String, Array{Symbol, 1}}()

    # REoptInputs indexed on segmented_techs
    segmented_techs = String[]  # no cost curves in BAU case because all techs have zero cap_cost_slope
    n_segs_by_tech = Dict{String, Int}()
    seg_min_size = Dict{String, Any}()
    seg_max_size = Dict{String, Any}()
    seg_yint = Dict{String, Any}()

    # PV specific arrays
    pv_to_location = DenseAxisArray{Int}(undef, pvtechs, p.pvlocations)

    levelization_factor = Dict(t => 1.0 for t in techs)

    for pvname in pvtechs  # copy the optimal scenario inputs for existing PV systems
        production_factor[pvname, :] = p.production_factor[pvname, :]
        pv_to_location[pvname, :, :] = p.pv_to_location[pvname, :, :]
        existing_sizes[pvname] = p.existing_sizes[pvname]
        min_sizes[pvname] = p.existing_sizes[pvname]
        max_sizes[pvname] = p.existing_sizes[pvname]
        n_segs_by_tech[pvname] = p.n_segs_by_tech[pvname]
        seg_min_size[pvname] = p.seg_min_size[pvname]
        seg_max_size[pvname] = p.seg_max_size[pvname]
        seg_yint[pvname] = p.seg_yint[pvname]
        om_cost_per_kw[pvname] = p.om_cost_per_kw[pvname]
        levelization_factor[pvname] = p.levelization_factor[pvname]
        cap_cost_slope[pvname] = p.cap_cost_slope[pvname]
        if pvname in p.pbi_techs
            push!(pbi_techs, pvname)
        end
        pv = findfirst(pv -> pv.name == pvname, p.s.pvs)
        fillin_techs_by_exportbin(techs_by_exportbin, pv, pv.name)
    end

    if "Generator" in techs
        max_sizes["Generator"] = p.s.generator.existing_kw
        min_sizes["Generator"] = p.s.generator.existing_kw
        existing_sizes["Generator"] = p.s.generator.existing_kw
        cap_cost_slope["Generator"] = p.s.generator.installed_cost_per_kw
        om_cost_per_kw["Generator"] = p.s.generator.om_cost_per_kw
        production_factor["Generator", :] = p.production_factor["Generator", :]
        fillin_techs_by_exportbin(techs_by_exportbin, p.s.generator, "Generator")
        if "Generator" in p.pbi_techs
            push!(pbi_techs, "Generator")
        end
    end

    # filling export_bins_by_tech MUST be done after techs_by_exportbin has been filled in
    for t in elec_techs
        export_bins_by_tech[t] = [bin for (bin, ts) in techs_by_exportbin if t in ts]
    end

    REoptInputs(
        bau_scenario,
        techs,
        pvtechs,
        gentechs,
        elec_techs,
        segmented_techs,
        pbi_techs,
        techs_no_turndown,
        min_sizes,
        max_sizes,
        existing_sizes,
        cap_cost_slope,
        om_cost_per_kw,
        p.time_steps,
        p.time_steps_with_grid,
        p.time_steps_without_grid,
        p.hours_per_timestep,
        p.months,
        production_factor,
        levelization_factor,
        p.value_of_lost_load_per_kwh,
        p.pwf_e,
        p.pwf_om,
        p.third_party_factor,
        p.pvlocations,
        p.maxsize_pv_locations,
        pv_to_location,
        p.ratchets,
        techs_by_exportbin,
        export_bins_by_tech,
        n_segs_by_tech,
        seg_min_size,
        seg_max_size,
        seg_yint,
        p.pbi_pwf, 
        p.pbi_max_benefit, 
        p.pbi_max_kw, 
        p.pbi_benefit_per_kwh
    )
end