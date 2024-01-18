# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
function add_ghp_constraints(m, p; _n="")
    # add_ghp_heating_elec was used in API's reopt_model.jl for "NewMaxSize" values, but these are not in REopt.jl currently
    # add_ghp_heating_elec = 1.0

    m[:GHPCapCosts] = @expression(m, p.third_party_factor *
        sum(p.ghp_installed_cost[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )

    m[:GHPOMCosts] = @expression(m, p.third_party_factor * p.pwf_om *
        sum(p.ghp_om_cost_year_one[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )

    if p.require_ghp_purchase == 1
        @constraint(m, GHPOptionSelect,
            sum(m[Symbol("binGHP"*_n)][g] for g in p.ghp_options) == 1
        )
    else
        @constraint(m, GHPOptionSelect,
            sum(m[Symbol("binGHP"*_n)][g] for g in p.ghp_options) <= 1
        )
    end

    m[:AvoidedCapexByGHP] = @expression(m,
        sum(p.avoided_capex_by_ghp_present_value[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )

    m[:ResidualGHXCapCost] = @expression(m,
        sum(p.ghx_residual_value[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )
    
    if p.s.ghp.can_serve_dhw
        @constraint(m, GHPDHWCon[ts in p.time_steps],
            m[Symbol("dvHeatingProduction"*_n)]["GHP","DomesticHotWater",ts] == 
            sum(p.ghp_heating_thermal_load_served_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
        )

        @constraint(m, GHPSpaceHeatingCon[ts in p.time_steps],
            m[Symbol("dvHeatingProduction"*_n)]["GHP","SpaceHeating",ts] == 
            sum(p.space_heating_thermal_load_reduction_with_ghp_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
        )
    else
        @constraint(m, GHPDHWCon[ts in p.time_steps],
            m[Symbol("dvHeatingProduction"*_n)]["GHP","DomesticHotWater",ts] == 0.0
        )

        @constraint(m, GHPSpaceHeatingCon[ts in p.time_steps],
            m[Symbol("dvHeatingProduction"*_n)]["GHP","SpaceHeating",ts] == 
            sum((p.space_heating_thermal_load_reduction_with_ghp_kw[g,ts] + p.ghp_heating_thermal_load_served_kw[g,ts]) * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
        )
    end

    @constraint(m, GHPCoolingCon[ts in p.time_steps],
        m[Symbol("dvCoolingProduction"*_n)]["GHP",ts] == 
        sum((p.cooling_thermal_load_reduction_with_ghp_kw[g,ts] + ghp_cooling_thermal_load_served_kw[g,ts]) * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )
    
end