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
    initial_capex = initial_capex_opt(m, p)
    if !isnothing(p.s.financial.min_initial_capital_costs_before_incentives)
        @constraint(m,
            initial_capex >= p.s.financial.min_initial_capital_costs_before_incentives
        )
    end
    if !isnothing(p.s.financial.max_initial_capital_costs_before_incentives)
        @constraint(m,
            initial_capex <= p.s.financial.max_initial_capital_costs_before_incentives
        )
    end
end

function initial_capex_opt(m::JuMP.AbstractModel, p::REoptInputs; _n="")
    initial_capex = p.s.financial.offgrid_other_capital_costs - m[Symbol("AvoidedCapexByASHP"*_n)] - m[Symbol("AvoidedCapexByGHP"*_n)]

    if !isempty(p.techs.gen) && isempty(_n)  # generators not included in multinode model
        initial_capex += p.s.generator.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Generator"]
    end

    if !isempty(p.techs.pv)
        for pv in p.s.pvs
            initial_capex += pv.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)][pv.name]
        end
    end

    for b in p.s.storage.types.elec
        if p.s.storage.attr[b].max_kw > 0
            initial_capex += p.s.storage.attr[b].installed_cost_per_kw * m[Symbol("dvStoragePower"*_n)][b] + 
                p.s.storage.attr[b].installed_cost_per_kwh * m[Symbol("dvStorageEnergy"*_n)][b]
        end
    end

    for b in p.s.storage.types.thermal
        if p.s.storage.attr[b].max_kw > 0
            initial_capex += p.s.storage.attr[b].installed_cost_per_kwh * m[Symbol("dvStorageEnergy"*_n)][b]
        end
    end

    if "Wind" in p.techs.all
        initial_capex += p.s.wind.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Wind"]
    end

    if "CHP" in p.techs.all
        chp_size_kw = m[Symbol("dvPurchaseSize"*_n)]["CHP"]
        initial_capex += get_chp_initial_capex(p, chp_size_kw)
    end

    if "SteamTurbine" in p.techs.all
        initial_capex += p.s.steam_turbine.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["SteamTurbine"]
    end

    if "Boiler" in p.techs.all
        initial_capex += p.s.boiler.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["Boiler"]
    end

    if "AbsorptionChiller" in p.techs.all
        initial_capex += p.s.absorption_chiller.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["AbsorptionChiller"]
    end

    if !isempty(p.s.ghp_option_list)

        for option in enumerate(p.s.ghp_option_list)

            if option[2].heat_pump_configuration == "WSHP"
                initial_capex += option[2].installed_cost_per_kw[2]*option[2].heatpump_capacity_ton*m[Symbol("binGHP"*_n)][option[1]]
            elseif option[2].heat_pump_configuration == "WWHP"
                initial_capex += (option[2].wwhp_heating_pump_installed_cost_curve[2]*option[2].wwhp_heating_pump_capacity_ton + option[2].wwhp_cooling_pump_installed_cost_curve[2]*option[2].wwhp_cooling_pump_capacity_ton)*m[Symbol("binGHP"*_n)][option[1]]
            else
                @warn "Unknown heat pump configuration provided, excluding GHP costs from initial capital costs."
            end
        end
    end

    if "ASHPSpaceHeater" in p.techs.all
        initial_capex += p.s.ashp.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["ASHPSpaceHeater"]
    end

    if "ASHPWaterHeater" in p.techs.all
        initial_capex += p.s.ashp_wh.installed_cost_per_kw * m[Symbol("dvPurchaseSize"*_n)]["ASHPWaterHeater"]
    end

    return initial_capex
end