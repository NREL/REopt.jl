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
function add_dv_UnservedLoad_constraints(m,p)
    # effective load balance (with slack in dvUnservedLoad)
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvUnservedLoad][s, tz, ts] >= p.s.electric_load.critical_loads_kw[tz+ts-1]
        - sum(  m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts-1] * p.levelization_factor[t]
              - m[:dvMGProductionToStorage][t, s, tz, ts] - m[:dvMGCurtail][t, s, tz, ts]
            for t in p.techs.elec
        )
        - m[:dvMGDischargeFromStorage][s, tz, ts]
    )
end

# constrain minimum hours that critical load is met
function add_min_hours_crit_ld_met_constraint(m,p)
    if p.s.site.min_resil_time_steps <= length(p.s.electric_utility.outage_time_steps)
        @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in 1:p.s.site.min_resil_time_steps],
            m[:dvUnservedLoad][s, tz, ts] <= 0
        )
    end
end

function add_outage_cost_constraints(m,p)
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMaxOutageCost][s] >= p.pwf_e * sum(p.value_of_lost_load_per_kwh[tz+ts-1] * m[:dvUnservedLoad][s, tz, ts] for ts in 1:p.s.electric_utility.outage_durations[s])
    )

    @expression(m, ExpectedOutageCost,
        sum(m[:dvMaxOutageCost][s] * p.s.electric_utility.outage_probabilities[s] for s in p.s.electric_utility.scenarios)
    )
   
    if !isempty(setdiff(p.techs.elec, p.techs.segmented))
        @constraint(m, [t in setdiff(p.techs.elec, p.techs.segmented)],
            m[:binMGTechUsed][t] => {m[:dvMGTechUpgradeCost][t] >= p.s.financial.microgrid_upgrade_cost_fraction * p.third_party_factor *
                                    p.cap_cost_slope[t] * m[:dvMGsize][t]}
        )
    end

    if !isempty(p.techs.segmented)
        @warn "Adding binary variable(s) to model cost curves in stochastic outages"
        @constraint(m, [t in p.techs.segmented],  # cannot have this for statement in sum( ... for t in ...) ???
            m[:binMGTechUsed][t] => {m[:dvMGTechUpgradeCost][t] >= p.s.financial.microgrid_upgrade_cost_fraction * p.third_party_factor * 
                sum(p.cap_cost_slope[t][s] * m[Symbol("dvSegmentSystemSize"*t)][s] + 
                    p.seg_yint[t][s] * m[Symbol("binSegment"*t)][s] for s in 1:p.n_segs_by_tech[t])}
            )
    end

    @constraint(m,
        m[:binMGStorageUsed] => {m[:dvMGStorageUpgradeCost] >= p.s.financial.microgrid_upgrade_cost_fraction * m[:TotalStorageCapCosts]}
    )
    
    @expression(m, mgTotalTechUpgradeCost,
        sum( m[:dvMGTechUpgradeCost][t] for t in p.techs.elec )
    )
end


function add_MG_size_constraints(m,p)
    @constraint(m, [t in p.techs.elec],
        m[:binMGTechUsed][t] => {m[:dvMGsize][t] >= 1.0}  # 1 kW min size to prevent binaryMGTechUsed = 1 with zero cost
    )

    @constraint(m, [b in p.s.storage.types.all],
        m[:binMGStorageUsed] => {m[:dvStoragePower][b] >= 1.0} # 1 kW min size to prevent binaryMGStorageUsed = 1 with zero cost
    )
    
    if p.s.site.mg_tech_sizes_equal_grid_sizes
        @constraint(m, [t in p.techs.elec],
            m[:dvMGsize][t] == m[:dvSize][t]
        )
    else
        @constraint(m, [t in p.techs.elec],
            m[:dvMGsize][t] <= m[:dvSize][t]
        )
    end
end


function add_MG_production_constraints(m,p)

	# Electrical production sent to storage or export must be less than technology's rated production
	@constraint(m, [t in p.techs.elec, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
		m[:dvMGProductionToStorage][t, s, tz, ts] + m[:dvMGCurtail][t, s, tz, ts] <=
		p.production_factor[t, tz+ts-1] * p.levelization_factor[t] * m[:dvMGRatedProduction][t, s, tz, ts]
    )

    @constraint(m, [t in p.techs.elec, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps], 
        m[:dvMGRatedProduction][t, s, tz, ts] >= 0
    )
    
    @constraint(m, [t in p.techs.elec, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvMGRatedProduction][t, s, tz, ts] <= m[:dvMGsize][t]
    )
end


function add_MG_fuel_burn_constraints(m,p)
	fuel_slope_gal_per_kwhe, fuel_intercept_gal_per_hr = generator_fuel_slope_and_intercept(
		electric_efficiency_full_load=p.s.generator.electric_efficiency_full_load, 
		electric_efficiency_half_load=p.s.generator.electric_efficiency_half_load
	)
    # Define dvMGFuelUsed by summing over outage time_steps.
    @constraint(m, [t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGFuelUsed][t, s, tz] == fuel_slope_gal_per_kwhe * p.hours_per_time_step * p.levelization_factor[t] *
        sum( p.production_factor[t, tz+ts-1] * m[:dvMGRatedProduction][t, s, tz, ts] for ts in 1:p.s.electric_utility.outage_durations[s])
        + fuel_intercept_gal_per_hr * p.hours_per_time_step * 
        sum( m[:binMGGenIsOnInTS][s, tz, ts] for ts in 1:p.s.electric_utility.outage_durations[s])
    )

    # For each outage the fuel used is <= fuel_avail_gal
    @constraint(m, [t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGFuelUsed][t, s, tz] <= p.s.generator.fuel_avail_gal
    )
    
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGMaxFuelUsage][s] >= sum( m[:dvMGFuelUsed][t, s, tz] for t in p.techs.gen )
    )
    
    @expression(m, ExpectedMGFuelUsed, 
        sum( m[:dvMGMaxFuelUsage][s] * p.s.electric_utility.outage_probabilities[s] for s in p.s.electric_utility.scenarios )
    )

    # fuel cost = gallons * $/gal for each tech, outage
    @expression(m, MGFuelCost[t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGFuelUsed][t, s, tz] * p.s.generator.fuel_cost_per_gallon
    )
    
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGMaxFuelCost][s] >= sum( MGFuelCost[t, s, tz] for t in p.techs.gen )
    )
    
    @expression(m, ExpectedMGFuelCost,
        sum( m[:dvMGMaxFuelCost][s] * p.s.electric_utility.outage_probabilities[s] for s in p.s.electric_utility.scenarios )
    )
end


function add_binMGGenIsOnInTS_constraints(m,p)
    # The following 2 constraints define binMGGenIsOnInTS to be the binary corollary to dvMGRatedProd for generator,
    # i.e. binMGGenIsOnInTS = 1 for dvMGRatedProd > min_turn_down_fraction * dvMGsize, and binMGGenIsOnInTS = 0 for dvMGRatedProd = 0
    @constraint(m, [t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        !m[:binMGGenIsOnInTS][s, tz, ts] => { m[:dvMGRatedProduction][t, s, tz, ts] <= 0 }
    )
    @constraint(m, [t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:binMGGenIsOnInTS][s, tz, ts] => { 
            m[:dvMGRatedProduction][t, s, tz, ts] >= p.s.generator.min_turn_down_fraction * m[:dvMGsize][t]
        }
    )
    @constraint(m, [t in p.techs.gen, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:binMGTechUsed][t] >= m[:binMGGenIsOnInTS][s, tz, ts]
    )
    # TODO? make binMGGenIsOnInTS indexed on p.techs.gen
end


function add_MG_storage_dispatch_constraints(m,p)
    # initial SOC at start of each outage equals the grid-optimal SOC
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps],
        m[:dvMGStoredEnergy][s, tz, 0] <= m[:dvStoredEnergy]["ElectricStorage", tz]
    )
    
    # state of charge
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvMGStoredEnergy][s, tz, ts] == m[:dvMGStoredEnergy][s, tz, ts-1] + p.hours_per_time_step * (
            p.s.storage.attr["ElectricStorage"].charge_efficiency * sum(m[:dvMGProductionToStorage][t, s, tz, ts] for t in p.techs.elec)
            - m[:dvMGDischargeFromStorage][s, tz, ts] / p.s.storage.attr["ElectricStorage"].discharge_efficiency
        )
    )

    # Minimum state of charge
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvMGStoredEnergy][s, tz, ts] >=  p.s.storage.attr["ElectricStorage"].soc_min_fraction * m[:dvStorageEnergy]["ElectricStorage"]
    )
    
    # Dispatch to MG electrical storage is no greater than inverter capacity
    # and can't charge the battery unless binMGStorageUsed = 1
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvStoragePower]["ElectricStorage"] >= sum(m[:dvMGProductionToStorage][t, s, tz, ts] for t in p.techs.elec)
    )
    
    # Dispatch from MG storage is no greater than inverter capacity
    # and can't discharge from storage unless binMGStorageUsed = 1
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvStoragePower]["ElectricStorage"] >= m[:dvMGDischargeFromStorage][s, tz, ts]
    )
    
    # Dispatch to and from electrical storage is no greater than power capacity
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvStoragePower]["ElectricStorage"] >= m[:dvMGDischargeFromStorage][s, tz, ts]
            + sum(m[:dvMGProductionToStorage][t, s, tz, ts] for t in p.techs.elec)
    )
    
    # State of charge upper bound is storage system size
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        m[:dvStorageEnergy]["ElectricStorage"] >= m[:dvMGStoredEnergy][s, tz, ts]
    )
    
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        !m[:binMGStorageUsed] => { sum(m[:dvMGProductionToStorage][t, s, tz, ts] for t in p.techs.elec) <= 0 }
    )
    
    @constraint(m, [s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
        !m[:binMGStorageUsed] => { m[:dvMGDischargeFromStorage][s, tz, ts] <= 0 }
    )
end


function fix_MG_storage_variables(m, p)
    fix(m[:dvMGStorageUpgradeCost], 0.0, force=true)
    fix(m[:binMGStorageUsed], 0, force=true)
    for s in p.s.electric_utility.scenarios
        for tz in p.s.electric_utility.outage_start_time_steps
            for ts in p.s.electric_utility.outage_time_steps
                fix(m[:dvMGDischargeFromStorage][s, tz, ts], 0.0, force=true)
                fix(m[:dvMGStoredEnergy][s, tz, ts], 0.0, force=true)
                for t in p.techs.elec
                    fix(m[:dvMGProductionToStorage][t, s, tz, ts], 0.0, force=true)
                end
            end
        end
    end
end


function add_cannot_have_MG_with_only_PVwind_constraints(m, p)
    renewable_techs = setdiff(p.techs.elec, p.techs.gen)
    # can't "turn down" renewable_techs
    if !isempty(renewable_techs)
        @constraint(m, [t in renewable_techs, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
            m[:binMGTechUsed][t] => { m[:dvMGRatedProduction][t, s, tz, ts] >= m[:dvMGsize][t] }
        )
        @constraint(m, [t in renewable_techs, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
            !m[:binMGTechUsed][t] => { m[:dvMGRatedProduction][t, s, tz, ts] <= 0 }
        )
        if !isempty(p.techs.gen) # PV or Wind alone cannot be used for a MG
            @constraint(m, [t in renewable_techs, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
                m[:binMGTechUsed][t] => { sum(m[:binMGTechUsed][tek] for tek in p.techs.gen) + m[:binMGStorageUsed] >= 1 }
            )
        else
            @constraint(m, [t in renewable_techs, s in p.s.electric_utility.scenarios, tz in p.s.electric_utility.outage_start_time_steps, ts in p.s.electric_utility.outage_time_steps],
                m[:binMGTechUsed][t] => { m[:binMGStorageUsed] >= 1 }
            )
        end
    end
end
