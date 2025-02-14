# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
function add_storage_size_constraints(m, p, b; _n="")
    # TODO add formal types for storage (i.e. "b")

	# Constraint (4b)-1: Lower bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] >= p.s.storage.attr[b].min_kwh
    )

	# Constraint (4b)-2: Upper bound on Storage Energy Capacity
	@constraint(m,
        m[Symbol("dvStorageEnergy"*_n)][b] <= p.s.storage.attr[b].max_kwh
    )

	# Constraint (4c)-1: Lower bound on Storage Power Capacity
	@constraint(m,
        m[Symbol("dvStoragePower"*_n)][b] >= p.s.storage.attr[b].min_kw
    )

	# Constraint (4c)-2: Upper bound on Storage Power Capacity
	@constraint(m,
        m[Symbol("dvStoragePower"*_n)][b] <= p.s.storage.attr[b].max_kw
    )
end


function add_general_storage_dispatch_constraints(m, p, b; _n="")
    # Constraint (4a): initial state of charge
	@constraint(m,
        m[Symbol("dvStoredEnergy"*_n)][b, 0] == p.s.storage.attr[b].soc_init_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
    )

    #Constraint (4n): State of charge upper bound is storage system size
    @constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b,ts] <= m[Symbol("dvStorageEnergy"*_n)][b]
    )

    # Constraint (4j): Minimum state of charge
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] >= p.s.storage.attr[b].soc_min_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
    )

    #Constraint (4j): Dispatch from storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts]
    )

end


function add_elec_storage_dispatch_constraints(m, p, b; _n="")
				
	# Constraint (4g): state-of-charge for electrical storage - with grid
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) 
            + p.s.storage.attr[b].grid_charge_efficiency * m[Symbol("dvGridToStorage"*_n)][b, ts] 
            - m[Symbol("dvDischargeFromStorage"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency
        )
	)

	# Constraint (4h): state-of-charge for electrical storage - no grid
	@constraint(m, [ts in p.time_steps_without_grid],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] == m[Symbol("dvStoredEnergy"*_n)][b, ts-1] + p.hours_per_time_step * (  
            sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.elec) 
            - m[Symbol("dvDischargeFromStorage"*_n)][b, ts] / p.s.storage.attr[b].discharge_efficiency
        )
    )

	# Constraint (4i)-1: Dispatch to electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) + m[Symbol("dvGridToStorage"*_n)][b, ts]
    )
	
	#Constraint (4k)-alt: Dispatch to and from electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps_with_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b, ts] + 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) + m[Symbol("dvGridToStorage"*_n)][b, ts]
    )

	#Constraint (4l)-alt: Dispatch from electrical storage is no greater than power capacity (no grid connection)
	@constraint(m, [ts in p.time_steps_without_grid],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b,ts] + 
            sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec)
    )
					
    # Remove grid-to-storage as an option if option to grid charge is turned off
    if !(p.s.storage.attr[b].can_grid_charge)
        for ts in p.time_steps_with_grid
            fix(m[Symbol("dvGridToStorage"*_n)][b, ts], 0.0, force=true)
        end
	end

    if p.s.storage.attr[b].minimum_avg_soc_fraction > 0
        avg_soc = sum(m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps) /
                   (8760. / p.hours_per_time_step)
        @constraint(m, avg_soc >= p.s.storage.attr[b].minimum_avg_soc_fraction * 
            sum(m[Symbol("dvStorageEnergy"*_n)][b])
        )
    end
end

function add_hot_thermal_storage_dispatch_constraints(m, p; _n="")

    # Constraint (4f)-1b: SteamTurbineTechs
	if !isempty(p.techs.steam_turbine)
		@constraint(m, SteamTurbineTechProductionFlowCon[b in p.s.storage.types.hot, t in p.techs.steam_turbine, q in p.heating_loads, ts in p.time_steps],
			m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] <=  m[Symbol("dvHeatingProduction"*_n)][t,q,ts]
			)
        @constraint(m, StorageToTurbineProductionFlowCon[b in p.s.storage.types.hot, q in p.heating_loads, ts in p.time_steps],
            m[Symbol("dvHeatFromStorageToTurbine"*_n)][b,q,ts] <= m[Symbol("dvHeatFromStorage"*_n)][b,q,ts]
        )
        for b in p.s.storage.types.hot
            if !p.s.storage.attr[b].can_supply_steam_turbine
                for q in p.heating_loads
                    for ts in p.time_steps
                        fix(m[Symbol("dvHeatFromStorageToTurbine"*_n)][b,q,ts], 0.0, force=true)
                    end
                end
            elseif p.s.storage.attr[b].supply_turbine_only
                @constraint(m, StorageOnlyToSteamTurbineCon[q in p.heating_loads, ts in p.time_steps],
                    m[Symbol("dvHeatFromStorage"*_n)][b,q,ts] ==  m[Symbol("dvHeatFromStorageToTurbine"*_n)][b,q,ts]
                    )
                for t in p.techs.steam_turbine
                    for ts in p.time_steps, q in p.heating_loads
                        fix(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts], 0.0, force=true)
                    end
                end
            end
        end
	end

    # Constraint (4j)-1: Reconcile state-of-charge for (hot) thermal storage
	@constraint(m, [b in setdiff(p.s.storage.types.hot, ["HotSensibleTes"]), ts in p.time_steps],
    m[Symbol("dvStoredEnergy"*_n)][b,ts] == m[Symbol("dvStoredEnergy"*_n)][b,ts-1] + (1/p.s.settings.time_steps_per_hour) * (
        p.s.storage.attr[b].charge_efficiency * sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for t in union(p.techs.heating, p.techs.chp), q in p.heating_loads) -
        sum(m[Symbol("dvHeatFromStorage"*_n)][b,q,ts] for q in p.heating_loads) / p.s.storage.attr[b].discharge_efficiency -
        p.s.storage.attr[b].thermal_decay_rate_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
        )
    )
    if "HotSensibleTes" in p.s.storage.types.hot
        @constraint(m, [b in intersect(p.s.storage.types.hot, ["HotSensibleTes"]), ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b,ts] == m[Symbol("dvStoredEnergy"*_n)][b,ts-1] + (1/p.s.settings.time_steps_per_hour) * (
            p.s.storage.attr[b].charge_efficiency * sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for t in union(p.techs.heating, p.techs.chp), q in p.heating_loads) -
            sum(m[Symbol("dvHeatFromStorage"*_n)][b,q,ts] for q in p.heating_loads) / p.s.storage.attr[b].discharge_efficiency -
            p.s.storage.attr[b].thermal_decay_rate_fraction * m[Symbol("dvStoredEnergy"*_n)][b, ts-1]
            )
        )
    end
    
    # # Reconcile dvStoragePower and dvStorageEnergy for HotSensibleTes
    # if "HotSensibleTes" in p.s.storage.types.hot
    #     @constraint(m, 
    #         m[Symbol("dvStoragePower"*_n)]["HotSensibleTes"] * p.s.storage.attr["HotSensibleTes"].num_hours == m[Symbol("dvStorageEnergy"*_n)]["HotSensibleTes"]
    #     )
    # end

    #Constraint (4n)-1: Dispatch to and from thermal storage is no greater than power capacity
	@constraint(m, [b in p.s.storage.types.hot, ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= 
        sum(m[Symbol("dvHeatFromStorage"*_n)][b,q,ts] + 
        sum(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts] for t in union(p.techs.heating, p.techs.chp))
        for q in p.heating_loads)
    )

    if "HotSensibleTes" in p.s.storage.types.hot
        @constraint(m, [ts in p.time_steps],
            m[Symbol("dvStorageEnergy"*_n)]["HotSensibleTes"] / p.s.storage.attr["HotSensibleTes"].num_charge_hours >= 
            sum(m[Symbol("dvHeatToStorage"*_n)]["HotSensibleTes",t,q,ts] for t in union(p.techs.heating, p.techs.chp), q in p.heating_loads)
        )
        @constraint(m, [ts in p.time_steps],
        m[Symbol("dvStorageEnergy"*_n)]["HotSensibleTes"] / p.s.storage.attr["HotSensibleTes"].num_discharge_hours  >= 
            sum(m[Symbol("dvHeatFromStorage"*_n)]["HotSensibleTes",q,ts] 
            for q in p.heating_loads)
        )
    end
    # TODO missing thermal storage constraints from API ???

    # Constraint (4o): Discharge from storage is equal to sum of heat from storage for all qualities
    @constraint(m, HeatDischargeReconciliation[b in p.s.storage.types.hot, ts in p.time_steps],
        m[Symbol("dvDischargeFromStorage"*_n)][b,ts] == 
        sum(m[Symbol("dvHeatFromStorage"*_n)][b,q,ts] for q in p.heating_loads)
    )

    #Do not allow GHP to charge storage
    if !isempty(p.techs.ghp)
        for b in p.s.storage.types.hot, t in p.techs.ghp, q in p.heating_loads, ts in p.time_steps
            fix(m[Symbol("dvHeatToStorage"*_n)][b,t,q,ts], 0.0, force=true)
        end
    end

    if "HotSensibleTes" in p.s.storage.types.hot && p.s.storage.attr["HotSensibleTes"].one_direction_flow
        dv = "binStorageCharge"*_n
        m[Symbol(dv)] = @variable(m, [p.s.storage.types.hot, p.time_steps], base_name=dv, binary=true)
        dv = "binStorageDischarge"*_n
        m[Symbol(dv)] = @variable(m, [p.s.storage.types.hot, p.time_steps], base_name=dv, binary=true)
        
        max_storage_power = min(p.s.storage.attr["HotSensibleTes"].max_kw, 
            100 * maximum(sum(p.heating_loads_kw[q][ts] for q in p.heating_loads) for ts in p.time_steps)    
        )
        
        @constraint(m, SensibleTesChargeMax[ts in p.time_steps],
            sum(m[Symbol("dvHeatToStorage"*_n)]["HotSensibleTes",t,q,ts] for t in union(p.techs.heating, p.techs.chp), q in p.heating_loads) <=
            max_storage_power * m[Symbol("binStorageCharge"*_n)]["HotSensibleTes",ts]
        )
        @constraint(m, SensibleTesDischargeMax[ts in p.time_steps],
            sum(m[Symbol("dvHeatFromStorage"*_n)]["HotSensibleTes",q,ts] for q in p.heating_loads) <=
            max_storage_power * m[Symbol("binStorageDischarge"*_n)]["HotSensibleTes",ts]
        )
        @constraint(m, SensibleTesFlowDirection[ts in p.time_steps],
            m[Symbol("binStorageDischarge"*_n)]["HotSensibleTes",ts] + m[Symbol("binStorageCharge"*_n)]["HotSensibleTes",ts] <= 1
        )
    end

end

function add_cold_thermal_storage_dispatch_constraints(m, p, b; _n="")

    # Constraint (4f)-2: (Cold) Thermal production sent to storage or grid must be less than technology's rated production
	if !isempty(p.techs.cooling)
		@constraint(m, CoolingTechProductionFlowCon[b in p.s.storage.types.cold, t in p.techs.cooling, ts in p.time_steps],
    	        m[Symbol("dvProductionToStorage"*_n)][b,t,ts]  <=
				m[Symbol("dvCoolingProduction"*_n)][t,ts]
				)
	end

    # Constraint (4j)-2: Reconcile state-of-charge for (cold) thermal storage
	@constraint(m, ColdTESInventoryCon[b in p.s.storage.types.cold, ts in p.time_steps],
    m[Symbol("dvStoredEnergy"*_n)][b,ts] == m[Symbol("dvStoredEnergy"*_n)][b,ts-1] + (1/p.s.settings.time_steps_per_hour) * (
        sum(p.s.storage.attr[b].charge_efficiency * m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.cooling) -
        m[Symbol("dvDischargeFromStorage"*_n)][b,ts]/p.s.storage.attr[b].discharge_efficiency -
        p.s.storage.attr[b].thermal_decay_rate_fraction * m[Symbol("dvStorageEnergy"*_n)][b]
        )
    )

    #Constraint (4n)-2: Dispatch to and from thermal storage is no greater than power capacity
    @constraint(m, [b in p.s.storage.types.cold, ts in p.time_steps],
        m[Symbol("dvStoragePower"*_n)][b] >= m[Symbol("dvDischargeFromStorage"*_n)][b,ts] + 
        sum(m[Symbol("dvProductionToStorage"*_n)][b,t,ts] for t in p.techs.cooling)
    )

    #Do not allow GHP to charge storage
    if !isempty(p.techs.ghp)
        for b in p.s.storage.types.cold, t in p.techs.ghp, ts in p.time_steps
                    fix(m[Symbol("dvProductionToStorage"*_n)][b,t,ts], 0.0, force=true)
        end
    end
end

function add_storage_sum_constraints(m, p; _n="")

	##Constraint (8c): Grid-to-storage no greater than grid purchases 
	@constraint(m, [ts in p.time_steps_with_grid],
      sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) >= 
      sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types.elec)
    )
end