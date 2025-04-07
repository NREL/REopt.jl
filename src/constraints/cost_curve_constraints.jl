# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
    add_cost_curve_vars_and_constraints(m, p; _n="")

There are two situations under which we add binary constraints to the model in order to create a segmented cost curve 
for a technology:
    1. When a technology has tax or investment incentives with upper capacity limits < tech.max_kw
        - first segment(s) have lower slope than last segment
    2. When a technology has multiple cost/size pairs (not implemented yet, used for CHP in v1)
        - we interpolate the slope between the cost/size points, typically with economies of scale pricing
We used to use cost curve segments for when a technology has a non-zero existing_kw by setting the first segment to a
zero cost (and slope) from zero kw to the existing_kw. Instead, we now have dvPurchaseSize >= dvSize - existing_kw.

To avoid unnecessary decision variables (and constraints) we use anonymous variables and register them in the model 
manually. With this method the decision variable containers do not have to be rectangular.
For example, (as implemented in v1 of the API) the decision variable dvSegmentSystemSize is indexed on 
[p.techs.all, p.Subdivision, p.Seg], where:
    - p.Subdivision is hardcoded to ["CapCost"] - and so it is unnecessary, 
    - p.Seg is the maximum number of segments in any cost curve
    - and p.techs.all includes all technologies
We can instead construct dvSegmentSystemSize as follows:
```julia
    for t in p.SegmentedTechs
        dv = "dvSegmentSystemSize" * t
        m[Symbol(dv)] = @variable(m, [1:p.SegSize[t]], base_name=dv)
    end
```
Then, for example, the dvSegmentSystemSize for Wind at segment 2 is accessed via:
```julia
    m[:dvSegmentSystemSizeWind][2]
```
In this fashion only technologies with more than one cost curve segment, and only the necessary amount of segments, are
modeled using the following binary variables and constraints.
"""
function add_cost_curve_vars_and_constraints(m, p; _n="")
    for t in p.techs.segmented
        dv = "dvSegmentSystemSize" * t
        m[Symbol(dv)] = @variable(m, [1:p.n_segs_by_tech[t]], base_name=dv, lower_bound=0)

        dv = "binSegment" * t
        m[Symbol(dv)] = @variable(m, [1:p.n_segs_by_tech[t]], base_name=dv, binary=true)
    end

    ##Constraint (7f)-1: Minimum segment size
    @constraint(m, SegmentSizeMinCon[t in p.techs.segmented, s in 1:p.n_segs_by_tech[t]],
        m[Symbol("dvSegmentSystemSize"*t)][s] >= p.seg_min_size[t][s] * m[Symbol("binSegment"*t)][s]
    )

    ##Constraint (7f)-2: Maximum segment size
    @constraint(m, SegmentSizeMaxCon[t in p.techs.segmented, s in 1:p.n_segs_by_tech[t]],
        m[Symbol("dvSegmentSystemSize"*t)][s] <= p.seg_max_size[t][s] * m[Symbol("binSegment"*t)][s]
    )

    ##Constraint (7g):  Segments add up to system size
    @constraint(m, SegmentSizeAddCon[t in p.techs.segmented],
        sum(m[Symbol("dvSegmentSystemSize"*t)][s] for s in 1:p.n_segs_by_tech[t]) == m[Symbol("dvPurchaseSize"*_n)][t]
    )

    ##Constraint (7h): At most one segment allowed
    @constraint(m, SegmentSelectCon[t in p.techs.segmented],
        sum(m[Symbol("binSegment"*t)][s] for s in 1:p.n_segs_by_tech[t]) <= 1
    )

    # Required for other constraints which are size-dependent; this is very similar to constraint in tech_constraints.jl, but has == instead of >=
    @constraint(m, [t in p.techs.segmented],
        m[Symbol("dvPurchaseSize"*_n)][t] == m[Symbol("dvSize"*_n)][t] - p.existing_sizes[t]
    )
end

function add_capex_constraints(m, p; _n="")
    @warn "Adding capital costs constraints. These may cause an infeasible problem in some cases, particularly for resilience runs."
    if !isnothing(p.s.financial.min_initial_capital_costs_before_incentives)
        @constraint(m,
            m[:InitialCapexNoIncentives] >= p.s.financial.min_initial_capital_costs_before_incentives
        )
    end
    if !isnothing(p.s.financial.max_initial_capital_costs_before_incentives)
        @constraint(m,
            m[:InitialCapexNoIncentives] <= p.s.financial.max_initial_capital_costs_before_incentives
        )
    end
end

function initial_capex(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    m[:InitialCapexNoIncentives] = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}(0.0) # Avoids MethodError
    
    add_to_expression!(m[:InitialCapexNoIncentives], 
        p.s.financial.offgrid_other_capital_costs - m[Symbol("AvoidedCapexByASHP"*_n)] - m[Symbol("AvoidedCapexByGHP"*_n)]
    )

    if !isempty(p.techs.gen) && isempty(_n)  # generators not included in multinode model
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.generator.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Generator"]
        )
    end

    if !isempty(p.techs.pv)
        for pv in p.s.pvs
            add_to_expression!(m[:InitialCapexNoIncentives], 
                pv.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)][pv.name]
            )
        end
    end

    for b in p.s.storage.types.elec
        if p.s.storage.attr[b].max_kw > 0
            add_to_expression!(m[:InitialCapexNoIncentives], 
                p.s.storage.attr[b].installed_cost_per_kw * m[Symbol("dvStoragePower"*_n)][b]
                + p.s.storage.attr[b].installed_cost_per_kwh * m[Symbol("dvStorageEnergy"*_n)][b]
            )
        end
    end

    for b in p.s.storage.types.thermal
        if p.s.storage.attr[b].max_kw > 0
            add_to_expression!(m[:InitialCapexNoIncentives], 
                p.s.storage.attr[b].installed_cost_per_kwh * m[Symbol("dvStorageEnergy"*_n)][b]
            )
        end
    end

    if "Wind" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.wind.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Wind"]
        )
    end

    if "CHP" in p.techs.all
        chp_size_kw = m[Symbol("dvPurchaseSize"*_n)]["CHP"]
        chp_capex = get_chp_initial_capex(m, p, chp_size_kw)
        add_to_expression!(m[:InitialCapexNoIncentives], chp_capex)
    end

    if "SteamTurbine" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.steam_turbine.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["SteamTurbine"]
        )
    end

    if "Boiler" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.boiler.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Boiler"]
        )
    end

    if "AbsorptionChiller" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.absorption_chiller.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["AbsorptionChiller"]
        )
    end

    if !isempty(p.s.ghp_option_list)
        for option in enumerate(p.s.ghp_option_list)
            if option[2].heat_pump_configuration == "WSHP"
                add_to_expression!(m[:InitialCapexNoIncentives], 
                    option[2].installed_cost_per_kw[2]*option[2].heatpump_capacity_ton*m[Symbol("binGHP"*_n)][option[1]]
                )
            elseif option[2].heat_pump_configuration == "WWHP"
                add_to_expression!(m[:InitialCapexNoIncentives], 
                    (option[2].wwhp_heating_pump_installed_cost_curve[2]*option[2].wwhp_heating_pump_capacity_ton + option[2].wwhp_cooling_pump_installed_cost_curve[2]*option[2].wwhp_cooling_pump_capacity_ton)*m[Symbol("binGHP"*_n)][option[1]]
                )
            else
                @warn "Unknown heat pump configuration provided, excluding GHP costs from initial capital costs."
            end
        end
    end

    if "ASHPSpaceHeater" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.ashp.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["ASHPSpaceHeater"]
        )
    end

    if "ASHPWaterHeater" in p.techs.all
        add_to_expression!(m[:InitialCapexNoIncentives], 
            p.s.ashp_wh.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["ASHPWaterHeater"]
        )
    end
end

""" 
    get_chp_initial_capex(m::JuMP.AbstractModel, p::REoptInputs, size_kw::Float64)

CHP has a cost-curve input option, so calculating the initial CapEx requires more logic than typical tech CapEx calcs
"""
function get_chp_initial_capex(m::JuMP.AbstractModel, p::REoptInputs, chp_size_kw)
    # CHP.installed_cost_per_kw is now a list with potentially > 1 elements
    cost_list = p.s.chp.installed_cost_per_kw
    size_list = p.s.chp.tech_sizes_for_cost_curve

    m[:CHPCapexNoIncentives] = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}() 

    if typeof(cost_list) == Vector{Float64}
        if chp_size_kw <= size_list[1]
            add_to_expression!(m[:CHPCapexNoIncentives], chp_size_kw * cost_list[1]) # Currently not handling non-zero cost ($) for 0 kW size input
        elseif chp_size_kw > size_list[end]
            add_to_expression!(m[:CHPCapexNoIncentives], chp_size_kw * cost_list[end])
        else
            for s in 2:length(size_list)
                if (chp_size_kw > size_list[s-1]) && (chp_size_kw <= size_list[s])
                    slope = (cost_list[s] * size_list[s] - cost_list[s-1] * size_list[s-1]) /
                            (size_list[s] - size_list[s-1])
                    add_to_expression!(m[:CHPCapexNoIncentives],  cost_list[s-1] * size_list[s-1] + (chp_size_kw - size_list[s-1]) * slope)
                end
            end
        end
    else
        add_to_expression!(m[:CHPCapexNoIncentives], cost_list * chp_size_kw)

    # TODO: Why was this commented out?
    #Add supplementary firing capital cost
    # chp_supp_firing_size = self.nested_outputs["Scenario"]["Site"][tech].get("size_supplementary_firing_kw")
    # chp_supp_firing_cost = self.inputs[tech].get("supplementary_firing_capital_cost_per_kw") or 0
    # add_to_expression!(m[:CHPCapexNoIncentives], chp_supp_firing_size * chp_supp_firing_cost)
    end

    return m[:CHPCapexNoIncentives]
end