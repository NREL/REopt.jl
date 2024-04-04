# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_boiler_tech_constraints(m, p; _n="")
    
    m[:TotalBoilerFuelCosts] = @expression(m, sum(p.pwf_fuel[t] *
        sum(m[:dvFuelUsage][t, ts] * p.fuel_cost_per_kwh[t][ts] for ts in p.time_steps)
        for t in p.techs.boiler)
    )

    # Constraint (1e): Total Fuel burn for Boiler
    @constraint(m, [t in p.techs.boiler, ts in p.time_steps],
        m[:dvFuelUsage][t,ts] == p.hours_per_time_step * (
            sum(m[Symbol("dvHeatingProduction"*_n)][t,q,ts] for q in p.heating_loads) / p.boiler_efficiency[t]
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
    @constraint(m, [t in setdiff(p.techs.heating, union(p.techs.elec, p.techs.ghp)), ts in p.time_steps],
        sum(m[Symbol("dvHeatingProduction"*_n)][t,q,ts] for q in p.heating_loads)  <= m[Symbol("dvSize"*_n)][t]
    )
    # Constraint (7_heating_load_compatability): Set production variables for incompatible heat loads to zero
    for t in setdiff(union(p.techs.heating, p.techs.chp), p.techs.ghp)
        if !(t in p.techs.can_serve_space_heating)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"SpaceHeating",ts], 0.0, force=true)
            end
        end
        if !(t in p.techs.can_serve_dhw)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"DomesticHotWater",ts], 0.0, force=true)
            end
        end
        if !(t in p.techs.can_serve_process_heat)
            for ts in p.time_steps
                fix(m[Symbol("dvHeatingProduction"*_n)][t,"ProcessHeat",ts], 0.0, force=true)
            end
        end
    end

    # If the electric heater can only provide heat to the storage system (as in PTES), then production to storage must equal total production
    if "ElectricHeater" in p.techs.electric_heater
        if p.s.electric_heater.charge_storage_only
            @constraint(m, ElectricHeaterOnlyChargesStorageCon[q in p.heating_loads, ts in p.time_steps],
                m[Symbol("dvHeatingProduction"*_n)]["ElectricHeater",q,ts] == sum(m[Symbol("dvHeatToStorage"*_n)][b,"ElectricHeater",q,ts] for b in p.s.storage.types.hot)
            )
        end
    end
end

function add_cooling_tech_constraints(m, p; _n="")
    # Constraint (7_cooling_prod_size): Production limit based on size for boiler
    @constraint(m, [t in setdiff(p.techs.cooling, p.techs.ghp), ts in p.time_steps_with_grid],
        m[Symbol("dvCoolingProduction"*_n)][t,ts] <= m[Symbol("dvSize"*_n)][t]
    )
    # The load balance for cooling is only applied to time_steps_with_grid, so make sure we don't arbitrarily show cooling production for time_steps_without_grid
    for t in setdiff(p.techs.cooling, p.techs.ghp)
        for ts in p.time_steps_without_grid
            fix(m[Symbol("dvCoolingProduction"*_n)][t, ts], 0.0, force=true)
        end
    end
end
