# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_boiler_tech_constraints(m, p; _n="")
    
    m[:TotalBoilerFuelCosts] = @expression(m, sum(p.pwf_fuel[t] *
        sum(m[:dvFuelUsage][t, ts] * p.fuel_cost_per_kwh[t][ts] for ts in p.time_steps)
        for t in p.techs.boiler)
    )

    # Constraint (1e): Total Fuel burn for Boiler
    @constraint(m, [t in p.techs.boiler, ts in p.time_steps],
        m[:dvFuelUsage][t,ts] == p.hours_per_time_step * (
            m[Symbol("dvThermalProduction"*_n)][t,ts] / p.boiler_efficiency[t]
        )
    )

    m[:TotalBoilerPerUnitProdOMCosts] = 0.0
    if "Boiler" in p.techs.boiler  # ExistingBoiler does not have om_cost_per_kwh
        m[:TotalBoilerPerUnitProdOMCosts] = @expression(m, p.third_party_factor * p.pwf_om *
            sum(p.s.boiler.om_cost_per_kwh / p.s.settings.time_steps_per_hour *
            m[:dvRatedProduction]["Boiler", ts] for ts in p.time_steps)
        )
    end
end

function add_heating_tech_constraints(m, p; _n="")
    # Constraint (7_heating_prod_size): Production limit based on size for non-electricity-producing heating techs
    @constraint(m, [t in setdiff(p.techs.heating, p.techs.elec), ts in p.time_steps],
        m[Symbol("dvThermalProduction"*_n)][t,ts] <= m[Symbol("dvSize"*_n)][t]
    )
end

function add_cooling_tech_constraints(m, p; _n="")
    # Constraint (7_cooling_prod_size): Production limit based on size for boiler
    @constraint(m, [t in p.techs.cooling, ts in p.time_steps_with_grid],
        m[Symbol("dvThermalProduction"*_n)][t,ts] <= m[Symbol("dvSize"*_n)][t]
    )
    # The load balance for cooling is only applied to time_steps_with_grid, so make sure we don't arbitrarily show cooling production for time_steps_without_grid
    for t in p.techs.cooling
        for ts in p.time_steps_without_grid
            fix(m[Symbol("dvThermalProduction"*_n)][t, ts], 0.0, force=true)
        end
    end
end
