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