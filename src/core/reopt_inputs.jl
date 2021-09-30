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
    REoptInputs

The data structure for all the inputs necessary to construct the JuMP model.
```julia
struct REoptInputs <: AbstractInputs
    s::AbstractScenario
    techs::Techs
    min_sizes::Dict{String, Float64}  # (techs)
    max_sizes::Dict{String, Float64}  # (techs)
    existing_sizes::Dict{String, Float64}  # (techs)
    cap_cost_slope::Dict{String, Any}  # (techs)
    om_cost_per_kw::Dict{String, Float64}  # (techs)
    time_steps::UnitRange
    time_steps_with_grid::Array{Int, 1}
    time_steps_without_grid::Array{Int, 1}
    hours_per_timestep::Float64
    months::UnitRange
    production_factor::DenseAxisArray{Float64, 2}  # (techs, time_steps)
    levelization_factor::Dict{String, Float64}  # (techs)
    value_of_lost_load_per_kwh::Array{R, 1} where R<:Real #default set to 1 US dollar per kwh
    pwf_e::Float64
    pwf_om::Float64
    third_party_factor::Float64
    pvlocations::Array{Symbol, 1}
    maxsize_pv_locations::DenseAxisArray{Float64, 1}  # indexed on pvlocations
    pv_to_location::Dict{String, Dict{Symbol, Int64}}  # (techs.pv, pvlocations)
    ratchets::UnitRange
    techs_by_exportbin::Dict{Symbol, AbstractArray}  # keys can include [:NEM, :WHL, :CUR]
    export_bins_by_tech::Dict
    n_segs_by_tech::Dict{String, Int}
    seg_min_size::Dict{String, Dict{Int, Float64}}
    seg_max_size::Dict{String, Dict{Int, Float64}}
    seg_yint::Dict{String, Dict{Int, Float64}}
    pbi_pwf::Dict{String, Any}  # (pbi_techs)
    pbi_max_benefit::Dict{String, Any}  # (pbi_techs)
    pbi_max_kw::Dict{String, Any}  # (pbi_techs)
    pbi_benefit_per_kwh::Dict{String, Any}  # (pbi_techs)
    boiler_efficiency::Dict{String, Float64}
end
```
"""
struct REoptInputs <: AbstractInputs
    s::AbstractScenario
    techs::Techs
    min_sizes::Dict{String, Float64}  # (techs)
    max_sizes::Dict{String, Float64}  # (techs)
    existing_sizes::Dict{String, Float64}  # (techs)
    cap_cost_slope::Dict{String, Any}  # (techs)
    om_cost_per_kw::Dict{String, Float64}  # (techs)
    time_steps::UnitRange
    time_steps_with_grid::Array{Int, 1}
    time_steps_without_grid::Array{Int, 1}
    hours_per_timestep::Float64
    months::UnitRange
    production_factor::DenseAxisArray{Float64, 2}  # (techs, time_steps)
    levelization_factor::Dict{String, Float64}  # (techs)
    value_of_lost_load_per_kwh::Array{R, 1} where R<:Real #default set to 1 US dollar per kwh
    pwf_e::Float64
    pwf_om::Float64
    pwf_fuel::Dict{String, Float64}
    third_party_factor::Float64
    pvlocations::Array{Symbol, 1}
    maxsize_pv_locations::DenseAxisArray{Float64, 1}  # indexed on pvlocations
    pv_to_location::Dict{String, Dict{Symbol, Int64}}  # (techs.pv, pvlocations)
    ratchets::UnitRange
    techs_by_exportbin::Dict{Symbol, AbstractArray}  # keys can include [:NEM, :WHL, :CUR]
    export_bins_by_tech::Dict
    n_segs_by_tech::Dict{String, Int}
    seg_min_size::Dict{String, Dict{Int, Float64}}
    seg_max_size::Dict{String, Dict{Int, Float64}}
    seg_yint::Dict{String, Dict{Int, Float64}}
    pbi_pwf::Dict{String, Any}  # (pbi_techs)
    pbi_max_benefit::Dict{String, Any}  # (pbi_techs)
    pbi_max_kw::Dict{String, Any}  # (pbi_techs)
    pbi_benefit_per_kwh::Dict{String, Any}  # (pbi_techs)
    boiler_efficiency::Dict{String, Float64}
end


"""
    REoptInputs(fp::String)

Use `fp` to load in JSON scenario:
```
function REoptInputs(fp::String)
    s = Scenario(JSON.parsefile(fp))
    REoptInputs(s)
end
```
Useful if you want to manually modify REoptInputs before solving the model.
"""
function REoptInputs(fp::String)
    s = Scenario(JSON.parsefile(fp))
    REoptInputs(s)
end


"""
    REoptInputs(s::AbstractScenario)

Constructor for REoptInputs. Translates the `Scenario` into all the data necessary for building the JuMP model.
"""
function REoptInputs(s::AbstractScenario)

    time_steps = 1:length(s.electric_load.loads_kw)
    hours_per_timestep = 1 / s.settings.time_steps_per_hour
    techs, pv_to_location, maxsize_pv_locations, pvlocations, 
        production_factor, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, n_segs_by_tech, 
        seg_min_size, seg_max_size, seg_yint, techs_by_exportbin, export_bins_by_tech, boiler_efficiency = 
        setup_tech_inputs(s)

    pbi_pwf, pbi_max_benefit, pbi_max_kw, pbi_benefit_per_kwh = setup_pbi_inputs(s, techs)

    months = 1:12

    levelization_factor, pwf_e, pwf_om, pwf_fuel, third_party_factor = setup_present_worth_factors(s, techs)
    # the following hardcoded values for levelization_factor matches the public REopt API value
    # and makes the test values match.
    # the REopt code herein uses the Desktop method for levelization_factor, which is more accurate
    # (Desktop has non-linear degradation vs. linear degradation in API)
    # levelization_factor = Dict("PV" => 0.9539)
    # levelization_factor = Dict("ground" => 0.942238, "roof_east" => 0.942238, "roof_west" => 0.942238)
    # levelization_factor = Dict("PV" => 0.9539, "Generator" => 1.0)
    time_steps_with_grid, time_steps_without_grid, = setup_electric_utility_inputs(s)
    
    if any(pv.existing_kw > 0 for pv in s.pvs)
        adjust_load_profile(s, production_factor)
    end

    REoptInputs(
        s,
        techs,
        min_sizes,
        max_sizes,
        existing_sizes,
        cap_cost_slope,
        om_cost_per_kw,
        time_steps,
        time_steps_with_grid,
        time_steps_without_grid,
        hours_per_timestep,
        months,
        production_factor,
        levelization_factor,
        typeof(s.financial.value_of_lost_load_per_kwh) <: Array{<:Real, 1} ? s.financial.value_of_lost_load_per_kwh : fill(s.financial.value_of_lost_load_per_kwh, length(time_steps)),
        pwf_e,
        pwf_om,
        pwf_fuel,
        third_party_factor,
        pvlocations,
        maxsize_pv_locations,
        pv_to_location,
        1:length(s.electric_tariff.tou_demand_ratchet_timesteps),  # ratchets
        techs_by_exportbin,
        export_bins_by_tech,
        n_segs_by_tech,
        seg_min_size,
        seg_max_size,
        seg_yint,
        pbi_pwf, 
        pbi_max_benefit, 
        pbi_max_kw, 
        pbi_benefit_per_kwh,
        boiler_efficiency
    )
end


"""
    function setup_tech_inputs(s::AbstractScenario)

Create data arrays associated with techs necessary to build the JuMP model.
"""
function setup_tech_inputs(s::AbstractScenario)

    techs = Techs(s)

    boiler_efficiency = Dict{String, Float64}()
    production_factor = DenseAxisArray{Float64}(undef, techs.all, 1:length(s.electric_load.loads_kw))

    # REoptInputs indexed on techs:
    max_sizes = Dict(t => 0.0 for t in techs.all)
    min_sizes = Dict(t => 0.0 for t in techs.all)
    existing_sizes = Dict(t => 0.0 for t in techs.all)
    cap_cost_slope = Dict{String, Any}()
    om_cost_per_kw = Dict(t => 0.0 for t in techs.all)

    # export related inputs
    techs_by_exportbin = Dict(k => [] for k in s.electric_tariff.export_bins)
    export_bins_by_tech = Dict{String, Array{Symbol, 1}}()

    # REoptInputs indexed on techs.segmented
    n_segs_by_tech = Dict{String, Int}()
    seg_min_size = Dict{String, Any}()
    seg_max_size = Dict{String, Any}()
    seg_yint = Dict{String, Any}()

    # PV specific arrays
    pvlocations = [:roof, :ground, :both]
    pv_to_location = Dict(t => Dict(loc => 0) for (t, loc) in zip(techs.pv, pvlocations))
    maxsize_pv_locations = DenseAxisArray([1.0e5, 1.0e5, 1.0e5], pvlocations)
    # default to large max size per location. Max size by roof, ground, both

    if !isempty(techs.pv)
        setup_pv_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor,
                        pvlocations, pv_to_location, maxsize_pv_locations, techs.segmented, n_segs_by_tech, 
                        seg_min_size, seg_max_size, seg_yint, techs_by_exportbin, techs.no_curtail)
    end

    if "Wind" in techs.all
        setup_wind_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor, 
            techs_by_exportbin, techs.segmented, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint, techs.no_curtail)
    end

    if "Generator" in techs.all
        setup_gen_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor,
            techs_by_exportbin, techs.segmented, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint, techs.no_curtail)
    end

    if "ExistingBoiler" in techs.all
        setup_existing_boiler_inputs(s, max_sizes, min_sizes, existing_sizes, cap_cost_slope, boiler_efficiency)
    end

    # filling export_bins_by_tech MUST be done after techs_by_exportbin has been filled in
    for t in techs.elec
        export_bins_by_tech[t] = [bin for (bin, ts) in techs_by_exportbin if t in ts]
    end

    return techs, pv_to_location, maxsize_pv_locations, pvlocations, 
    production_factor, max_sizes, min_sizes, existing_sizes, cap_cost_slope, om_cost_per_kw, n_segs_by_tech, 
    seg_min_size, seg_max_size, seg_yint, techs_by_exportbin, export_bins_by_tech, boiler_efficiency
end


"""
    setup_pbi_inputs(s::AbstractScenario, techs::Techs)

Create data arrays for production based incentives. 
All arrays can be empty if no techs have production_incentive_per_kwh > 0.
"""
function setup_pbi_inputs(s::AbstractScenario, techs::Techs)

    pbi_pwf = Dict{String, Any}()
    pbi_max_benefit = Dict{String, Any}()
    pbi_max_kw = Dict{String, Any}()
    pbi_benefit_per_kwh = Dict{String, Any}()

    for tech in techs.all
        if !(tech in techs.pv)
            T = typeof(eval(Meta.parse(tech)))
            if :production_incentive_per_kwh in fieldnames(T)
                if eval(Meta.parse("s."*tech*".production_incentive_per_kwh")) > 0
                    push!(techs.pbi, tech)
                    pbi_pwf[tech], pbi_max_benefit[tech], pbi_max_kw[tech], pbi_benefit_per_kwh[tech] = 
                        production_incentives(eval(Meta.parse("s."*tech)), s.financial)
                end
            end
        else
            pv = get_pv_by_name(tech, s.pvs)
            if pv.production_incentive_per_kwh > 0
                push!(techs.pbi, tech)
                pbi_pwf[tech], pbi_max_benefit[tech], pbi_max_kw[tech], pbi_benefit_per_kwh[tech] = 
                    production_incentives(pv, s.financial)
            end
        end
        
    end
    return pbi_pwf, pbi_max_benefit, pbi_max_kw, pbi_benefit_per_kwh
end


"""
    update_cost_curve!(tech::AbstractTech, tech_name::String, financial::Financial,
        cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint
    )

Modifies cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint based on tech attributes.
In the simplest case (zero incentives, no existing_kw) the cap_cost_slope is updated with:
```julia
    cap_cost_slope[tech_name] = tech.installed_cost_per_kw
```
However, if there are non-zero incentives or `existing_kw` then there will be more than one cost curve segment typically
and all of the other arguments will be updated as well.
"""
function update_cost_curve!(tech::AbstractTech, tech_name::String, financial::Financial,
    cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint
    )
    cost_slope, cost_curve_bp_x, cost_yint, n_segments = cost_curve(tech, financial)
    cap_cost_slope[tech_name] = cost_slope[1]
    if n_segments > 1
        cap_cost_slope[tech_name] = cost_slope
        push!(segmented_techs, tech_name)
        seg_max_size[tech_name] = Dict{Int,Float64}()
        seg_min_size[tech_name] = Dict{Int,Float64}()
        n_segs_by_tech[tech_name] = n_segments
        seg_yint[tech_name] = Dict{Int,Float64}()
        for s in 1:n_segments
            seg_min_size[tech_name][s] = cost_curve_bp_x[s]
            seg_max_size[tech_name][s] = cost_curve_bp_x[s+1]
            seg_yint[tech_name][s] = cost_yint[s]
        end
    end
    nothing
end


function setup_pv_inputs(s::AbstractScenario, max_sizes, min_sizes,
    existing_sizes, cap_cost_slope, om_cost_per_kw, production_factor,
    pvlocations, pv_to_location, maxsize_pv_locations, 
    segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint, techs_by_exportbin, techs_no_curtail)

    pv_roof_limited, pv_ground_limited, pv_space_limited = false, false, false
    roof_existing_pv_kw, ground_existing_pv_kw, both_existing_pv_kw = 0.0, 0.0, 0.0
    roof_max_kw, land_max_kw = 1.0e5, 1.0e5

    for pv in s.pvs
        production_factor[pv.name, :] = prodfactor(pv, s.site.latitude, s.site.longitude)
        for location in pvlocations
            if pv.location == location
                pv_to_location[pv.name][location] = 1
            else
                pv_to_location[pv.name][location] = 0
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

        update_cost_curve!(pv, pv.name, s.financial,
            cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint
        )
        
        om_cost_per_kw[pv.name] = pv.om_cost_per_kw
        fillin_techs_by_exportbin(techs_by_exportbin, pv, pv.name)

        if !pv.can_curtail
            push!(techs_no_curtail, pv.name)
        end
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


function setup_wind_inputs(s::AbstractScenario, max_sizes, min_sizes, existing_sizes,
    cap_cost_slope, om_cost_per_kw, production_factor, techs_by_exportbin,
    segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint, techs_no_curtail
    )
    max_sizes["Wind"] = s.wind.max_kw
    min_sizes["Wind"] = s.wind.min_kw
    existing_sizes["Wind"] = 0.0
    update_cost_curve!(s.wind, "Wind", s.financial,
        cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint
    )
    om_cost_per_kw["Wind"] = s.wind.om_cost_per_kw
    production_factor["Wind", :] = prodfactor(s.wind, s.site.latitude, s.site.longitude, s.settings.time_steps_per_hour)
    fillin_techs_by_exportbin(techs_by_exportbin, s.wind, "Wind")
    if !s.wind.can_curtail
        push!(techs_no_curtail, "Wind")
    end
    return nothing
end


function setup_gen_inputs(s::AbstractScenario, max_sizes, min_sizes, existing_sizes,
    cap_cost_slope, om_cost_per_kw, production_factor, techs_by_exportbin,
    segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint, techs_no_curtail
    )
    max_sizes["Generator"] = s.generator.max_kw
    min_sizes["Generator"] = s.generator.existing_kw + s.generator.min_kw
    existing_sizes["Generator"] = s.generator.existing_kw
    update_cost_curve!(s.generator, "Generator", s.financial,
        cap_cost_slope, segmented_techs, n_segs_by_tech, seg_min_size, seg_max_size, seg_yint
    )
    om_cost_per_kw["Generator"] = s.generator.om_cost_per_kw
    production_factor["Generator", :] = prodfactor(s.generator)
    fillin_techs_by_exportbin(techs_by_exportbin, s.generator, "Generator")
    if !s.generator.can_curtail
        push!(techs_no_curtail, "Generator")
    end
    return nothing
end


function setup_existing_boiler_inputs(s::AbstractScenario, max_sizes, min_sizes, existing_sizes, cap_cost_slope, boiler_efficiency)
    max_sizes["ExistingBoiler"] = s.existing_boiler.max_kw
    min_sizes["ExistingBoiler"] = 0.0
    existing_sizes["ExistingBoiler"] = 0.0
    cap_cost_slope["ExistingBoiler"] = 0.0
    boiler_efficiency["ExistingBoiler"] = s.existing_boiler.efficiency
    # om_cost_per_kw["ExistingBoiler"] = 0.0
    return nothing
end


function setup_present_worth_factors(s::AbstractScenario, techs::Techs)

    lvl_factor = Dict(t => 1.0 for t in techs.all)  # default levelization_factor of 1.0
    for (i, tech) in enumerate(techs.pv)  # replace 1.0 with actual PV levelization_factor (only tech with degradation)
        lvl_factor[tech] = levelization_factor(
            s.financial.analysis_years,
            s.financial.elec_cost_escalation_pct,
            s.financial.offtaker_discount_pct,
            s.pvs[i].degradation_pct  # TODO generalize for any tech (not just pvs)
        )
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
    pwf_fuel = Dict{String, Float64}()
    for t in techs.fuel_burning
        if t == "ExistingBoiler"
            pwf_fuel["ExistingBoiler"] = annuity(
                s.financial.analysis_years,
                s.financial.boiler_fuel_cost_escalation_pct,
                s.financial.offtaker_discount_pct
            )
        end
    end

    if s.financial.third_party_ownership
        pwf_offtaker = annuity(s.financial.analysis_years, 0.0, s.financial.offtaker_discount_pct)
        pwf_owner = annuity(s.financial.analysis_years, 0.0, s.financial.owner_discount_pct)
        third_party_factor = (pwf_offtaker * (1 - s.financial.offtaker_tax_pct)) /
                           (pwf_owner * (1 - s.financial.owner_tax_pct))
    else
        third_party_factor = 1.0
    end

    return lvl_factor, pwf_e, pwf_om, pwf_fuel, third_party_factor
end


"""
    setup_electric_utility_inputs(s::AbstractScenario)

Define the `time_steps_with_grid` and `time_steps_without_grid` (detministic outage).

NOTE: v1 of the API spliced the critical_loads_kw into the loads_kw during outages but this splicing is no longer needed
now that the constraints are properly applied over `time_steps_with_grid` and `time_steps_without_grid` using loads_kw
and critical_loads_kw respectively.
"""
function setup_electric_utility_inputs(s::AbstractScenario)
    if s.electric_utility.outage_end_time_step > 0 &&
            s.electric_utility.outage_end_time_step > s.electric_utility.outage_start_time_step
        time_steps_without_grid = Int[i for i in range(s.electric_utility.outage_start_time_step,
                                                    stop=s.electric_utility.outage_end_time_step)]
        if s.electric_utility.outage_start_time_step > 1
            time_steps_with_grid = append!(
                Int[i for i in range(1, stop=s.electric_utility.outage_start_time_step - 1)],
                Int[i for i in range(s.electric_utility.outage_end_time_step + 1,
                                     stop=length(s.electric_load.loads_kw))]
            )
        else
            time_steps_with_grid = Int[i for i in range(s.electric_utility.outage_end_time_step + 1,
                                       stop=length(s.electric_load.loads_kw))]
        end
    else
        time_steps_without_grid = Int[]
        time_steps_with_grid = Int[i for i in range(1, stop=length(s.electric_load.loads_kw))]
    end
    return time_steps_with_grid, time_steps_without_grid
end


"""
    adjust_load_profile(s::AbstractScenario, production_factor::DenseAxisArray)

Adjust the (critical_)loads_kw based off of (critical_)loads_kw_is_net
"""
function adjust_load_profile(s::AbstractScenario, production_factor::DenseAxisArray)
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


"""
    production_incentives(tech::AbstractTech, financial::Financial)

Intermediate function for building the PBI arrays in REoptInputs
"""
function production_incentives(tech::AbstractTech, financial::Financial)
    pwf_prod_incent = 0.0
    max_prod_incent = 0.0
    max_size_for_prod_incent = 0.0
    production_incentive_rate = 0.0
    T = typeof(tech)
    # TODO should Generator be excluded? (v1 has the PBI inputs for Generator)
    if !(nameof(T) in [:Generator, :Boiler, :Elecchl, :Absorpchl])
        if :degradation_pct in fieldnames(T)  # PV has degradation
            pwf_prod_incent = annuity_escalation(tech.production_incentive_years, -1*tech.degradation_pct,
                                                 financial.owner_discount_pct)
        else
            # prod incentives have zero escalation rate
            pwf_prod_incent = annuity(tech.production_incentive_years, 0, financial.owner_discount_pct)
        end
        max_prod_incent = tech.production_incentive_max_benefit
        max_size_for_prod_incent = tech.production_incentive_max_kw
        production_incentive_rate = tech.production_incentive_per_kwh
    end

    return pwf_prod_incent, max_prod_incent, max_size_for_prod_incent, production_incentive_rate
end


function fillin_techs_by_exportbin(techs_by_exportbin::Dict, tech::AbstractTech, tech_name::String)
    if tech.can_net_meter && :NEM in keys(techs_by_exportbin)
        push!(techs_by_exportbin[:NEM], tech_name)
        if tech.can_export_beyond_nem_limit && :EXC in keys(techs_by_exportbin)
            push!(techs_by_exportbin[:EXC], tech_name)
        end
    end
    
    if tech.can_wholesale && :WHL in keys(techs_by_exportbin)
        push!(techs_by_exportbin[:WHL], tech_name)
    end
    return nothing
end