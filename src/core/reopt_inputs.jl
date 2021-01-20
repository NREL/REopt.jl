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

use Scenario struct to create reopt.jl model inputs
"""

struct REoptInputs
    techs::Array{String, 1}
    pvtechs::Array{String, 1}
    gentechs::Array{String,1}
    elec_techs::Array{String, 1}
    techs_no_turndown::Array{String, 1}
    min_sizes::DenseAxisArray{Float64, 1}  # (techs)
    max_sizes::DenseAxisArray{Float64, 1}  # (techs)
    existing_sizes::DenseAxisArray{Float64, 1}  # (techs)
    cap_cost_slope::DenseAxisArray{Float64, 1}  # (techs)
    om_cost_per_kw::DenseAxisArray{Float64, 1}  # (techs)
    max_grid_export_kwh::Float64
    elec_load::ElectricLoad
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
    owner_tax_pct::Float64
    offtaker_tax_pct::Float64
    microgrid_premium_pct::Float64
    pvlocations::Array{Symbol, 1}
    maxsize_pv_locations::DenseAxisArray{Float64, 1}  # indexed on pvlocations
    pv_to_location::DenseAxisArray{Int, 2}  # (pv_techs, pvlocations)
    etariff::ElectricTariff
    ratchets::UnitRange
    techs_by_exportbin::DenseAxisArray{Array{String,1}}  # indexed on [:NEM, :WHL, :CUR]
    storage::Storage
    generator::Generator
    elecutil::ElectricUtility
    min_resil_timesteps::Int
    mg_tech_sizes_equal_grid_sizes::Bool
    node::Int
end

function REoptInputs(fp::String)
    s = Scenario(JSON.parsefile(fp))
    REoptInputs(s)
end

function REoptInputs(s::Scenario)

    time_steps = 1:length(s.electric_load.loads_kw)
    hours_per_timestep = 8760.0 / length(s.electric_load.loads_kw)
    techs, pvtechs, gentechs, pv_to_location, maxsize_pv_locations, pvlocations, production_factor,
        max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw  = setup_tech_inputs(s)
    elec_techs = techs  # only modeling electric loads/techs so far
    techs_no_turndown = pvtechs

    max_grid_export_kwh = sum(s.electric_load.loads_kw)

    months = 1:length(s.electric_tariff.monthly_demand_rates)

    techs_by_exportbin = DenseAxisArray([ techs, techs, techs], s.electric_tariff.export_bins)
    # TODO account for which techs have access to export bins (when we add more techs than PV)

    levelization_factor, pwf_e, pwf_om, two_party_factor = setup_present_worth_factors(s, techs, pvtechs)
    # the following hardcoded value for levelization_factor matches the public REopt API value
    # for test_with_cplex (test_time_of_export_rate) and makes the test values match.
    # the REopt code herein uses the Desktop method for levelization_factor, which is more accurate
    # (Desktop has non-linear degradation vs. linear degradation in API)
    # levelization_factor = DenseAxisArray([0.9539], techs)
    # levelization_factor = DenseAxisArray([0.9539, 1.0], techs)  # w/generator
    time_steps_with_grid, time_steps_without_grid, = setup_electric_utility_inputs(s)
    
    if any(pv.existing_kw > 0 for pv in s.pvs)
        adjust_load_profile(s, production_factor)
    end

    REoptInputs(
        techs,
        pvtechs,
        gentechs,
        elec_techs,
        techs_no_turndown,
        min_sizes,
        max_sizes,
        existing_sizes,
        cap_cost_slope,
        om_cost_per_kw,
        max_grid_export_kwh,
        s.electric_load,
        time_steps,
        time_steps_with_grid,
        time_steps_without_grid,
        hours_per_timestep,
        months,
        production_factor,
        levelization_factor,
        typeof(s.financial.VoLL) <: Array{<:Real, 1} ? s.financial.VoLL : fill(s.financial.VoLL, length(time_steps)),
        pwf_e,
        pwf_om,
        two_party_factor,
        s.financial.owner_tax_pct,
        s.financial.offtaker_tax_pct,
        s.financial.microgrid_premium_pct,
        pvlocations,
        maxsize_pv_locations,
        pv_to_location,
        s.electric_tariff,
        1:length(s.electric_tariff.tou_demand_ratchet_timesteps),  # ratchets
        techs_by_exportbin,
        s.storage,
        s.generator,
        s.electric_utility,
        s.site.min_resil_timesteps,
        s.site.mg_tech_sizes_equal_grid_sizes,
        s.site.node
    )
end

function setup_tech_inputs(s::Scenario)

    pvtechs = String[pv.name for pv in s.pvs]
    if length(Base.Set(pvtechs)) != length(pvtechs)
        error("PV names must be unique, got $(pvtechs)")
    end

    techs = copy(pvtechs)
    gentechs = String[]
    if s.generator.max_kw > 0
        push!(techs, "Generator")
        push!(gentechs, "Generator")
    end

    time_steps = 1:length(s.electric_load.loads_kw)

    # REoptInputs indexed on techs:
    max_sizes = DenseAxisArray{Float64}(undef, techs)
    min_sizes = DenseAxisArray{Float64}(undef, techs)
    existing_sizes = DenseAxisArray{Float64}(undef, techs)
    cap_cost_slope = DenseAxisArray{Float64}(undef, techs)
    om_cost_per_kw = DenseAxisArray{Float64}(undef, techs)
    production_factor = DenseAxisArray{Float64}(undef, techs, time_steps)

    # PV specific arrays
    pvlocations = [:roof, :ground, :both]
    pv_to_location = DenseAxisArray{Int}(undef, pvtechs, pvlocations)
    maxsize_pv_locations = DenseAxisArray([1.0e5, 1.0e5, 1.0e5], pvlocations)
    # default to large max size per location. Max size by roof, ground, both

    if !isempty(pvtechs)
        setup_pv_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor,
                        pvlocations, pv_to_location, maxsize_pv_locations)
    end

    if "Generator" in techs
        setup_gen_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor)
    end

    return techs, pvtechs, gentechs, pv_to_location, maxsize_pv_locations, pvlocations, production_factor,
    max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw
end


function setup_pv_inputs(s::Scenario, max_sizes, min_sizes,
    existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor,
    pvlocations, pv_to_location, maxsize_pv_locations)

    time_steps = 1:length(s.electric_load.loads_kw)

    pv_roof_limited, pv_ground_limited, pv_space_limited = false, false, false
    roof_existing_pv_kw, ground_existing_pv_kw, both_existing_pv_kw = 0.0, 0.0, 0.0
    roof_max_kw, land_max_kw = 1.0e5, 1.0e5

    for pv in s.pvs
        production_factor[pv.name, :] = prodfactor(pv, s.site.latitude, s.site.longitude)
        for location in pvlocations
            if pv.location == location
                pv_to_location[pv.name, location] = 1
            else
                pv_to_location[pv.name, location] = 0
            end
        end

        beyond_existing_kw = pv.max_kw
        if pv.location == "both"
            both_existing_pv_kw += pv.existing_kw
            if !(s.site.roof_squarefeet === nothing) && !(s.site.land_acres === nothing)
                # don"t restrict unless both land_area and roof_area specified,
                # otherwise one of them is "unlimited"
                roof_max_kw = s.site.roof_squarefeet * pv.kw_per_square_foot
                land_max_kw = s.site.land_acres / pv.acres_per_kw
                beyond_existing_kw = min(roof_max_kw + land_max_kw, beyond_existing_kw)
                pv_space_limited = true
            end
        elseif pv.location == "roof"
            roof_existing_pv_kw += pv.existing_kw
            if !(s.site.roof_squarefeet === nothing)
                roof_max_kw = s.site.roof_squarefeet * pv.kw_per_square_foot
                beyond_existing_kw = min(roof_max_kw, beyond_existing_kw)
                pv_roof_limited = true
            end

        elseif pv.location == "ground"
            ground_existing_pv_kw += pv.existing_kw
            if !(s.site.land_acres === nothing)
                land_max_kw = s.site.land_acres / pv.acres_per_kw
                beyond_existing_kw = min(land_max_kw, beyond_existing_kw)
                pv_ground_limited = true
            end
        end

        existing_sizes[pv.name] = pv.existing_kw
        min_sizes[pv.name] = pv.existing_kw + pv.min_kw
        max_sizes[pv.name] = pv.existing_kw + beyond_existing_kw

        cap_cost_slope[pv.name] = effective_cost(;
            itc_basis=pv.cost_per_kw,
            replacement_cost=0.0,
            replacement_year=s.financial.analysis_years,
            discount_rate=s.financial.owner_discount_pct,
            tax_rate=s.financial.owner_tax_pct,
            itc=pv.total_itc_pct,
            macrs_schedule = pv.macrs_option_years == 7 ? s.financial.macrs_seven_year : s.financial.macrs_five_year,
            macrs_bonus_pct=pv.macrs_bonus_pct,
            macrs_itc_reduction = pv.macrs_itc_reduction,
            rebate_per_kw = pv.total_rebate_per_kw
        )
        
        om_cost_per_kw[pv.name] = pv.om_cost_per_kw
    end

    if pv_roof_limited
        maxsize_pv_locations[:roof] = float(roof_existing_pv_kw + roof_max_kw)
    end
    if pv_ground_limited
        maxsize_pv_locations[:ground] = float(ground_existing_pv_kw + land_max_kw)
    end
    if pv_space_limited
        maxsize_pv_locations[:both] = float(both_existing_pv_kw + roof_max_kw + land_max_kw)
    end

    return nothing
end


function setup_gen_inputs(s::Scenario, max_sizes, min_sizes, existing_sizes,
    cap_cost_slope, om_cost_per_kw, production_factor)

    max_sizes["Generator"] = s.generator.max_kw
    min_sizes["Generator"] = s.generator.existing_kw + s.generator.min_kw
    existing_sizes["Generator"] = s.generator.existing_kw
    cap_cost_slope["Generator"] = s.generator.cost_per_kw
    om_cost_per_kw["Generator"] = s.generator.om_cost_per_kw
    production_factor["Generator", :] = prodfactor(s.generator)
    return nothing
end


function setup_present_worth_factors(s::Scenario, techs::Array{String, 1}, pvtechs::Array{String, 1})

    lvl_factor = DenseAxisArray{Float64}(undef, techs)
    for (i, tech) in enumerate(pvtechs)
        lvl_factor[tech] = levelization_factor(
            s.financial.analysis_years,
            s.financial.elec_cost_escalation_pct,
            s.financial.offtaker_discount_pct,
            s.pvs[i].degradation_pct  # TODO generalize for any tech (not just pvs)
        )
    end
    if "Generator" in techs
        lvl_factor["Generator"] = 1
    end

    pwf_e = annuity(
        s.financial.analysis_years,
        s.financial.elec_cost_escalation_pct,
        s.financial.offtaker_discount_pct
    )

    pwf_om = annuity(
        s.financial.analysis_years,
        s.financial.om_cost_escalation_pct,
        s.financial.owner_discount_pct
    )

    if s.financial.two_party_ownership
        pwf_offtaker = annuity(s.financial.analysis_years, 0.0, s.financial.offtaker_discount_pct)
        pwf_owner = annuity(s.financial.analysis_years, 0.0, s.financial.owner_discount_pct)
        two_party_factor = (pwf_offtaker * (1 - s.financial.offtaker_tax_pct)) /
                           (pwf_owner * (1 - s.financial.owner_tax_pct))
    else
        two_party_factor = 1.0
    end

    return lvl_factor, pwf_e, pwf_om, two_party_factor
end


function setup_electric_utility_inputs(s::Scenario)
    if s.electric_utility.outage_end_timestep > 0 &&
            s.electric_utility.outage_end_timestep > s.electric_utility.outage_start_timestep
        time_steps_without_grid = Int[i for i in range(s.electric_utility.outage_start_timestep,
                                                    stop=s.electric_utility.outage_end_timestep)]
        if s.electric_utility.outage_start_timestep > 1
            time_steps_with_grid = append!(
                Int[i for i in range(1, stop=s.electric_utility.outage_start_timestep - 1)],
                Int[i for i in range(s.electric_utility.outage_end_timestep + 1,
                                     stop=length(s.electric_load.loads_kw))]
            )
        else
            time_steps_with_grid = Int[i for i in range(s.electric_utility.outage_end_timestep + 1,
                                       stop=length(s.electric_load.loads_kw))]
        end
    else
        time_steps_without_grid = Int[]
        time_steps_with_grid = Int[i for i in range(1, stop=length(s.electric_load.loads_kw))]
    end
    return time_steps_with_grid, time_steps_without_grid
end


function adjust_load_profile(s::Scenario, production_factor::DenseAxisArray)
    if s.electric_load.loads_kw_is_net
        for pv in s.pvs if pv.existing_kw > 0
            s.electric_load.loads_kw .+= pv.existing_kw * production_factor[pv.name, :].data
        end end
    end
    
    if s.electric_load.critical_loads_kw_is_net
        for pv in s.pvs if pv.existing_kw > 0
            s.electric_load.critical_loads_kw .+= pv.existing_kw * production_factor[pv.name, :].data
        end end
    end
end