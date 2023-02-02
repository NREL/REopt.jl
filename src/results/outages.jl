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
`Outages` results keys:
- `expected_outage_cost` The expected outage cost over the random outages modeled.
- `max_outage_cost_per_outage_duration` The maximum outage cost in every outage duration modeled.
- `unserved_load_series` The amount of unserved load in each outage and each time step.
- `unserved_load_per_outage` The total unserved load in each outage.
- `mg_storage_upgrade_cost` The cost to include the storage system in the microgrid.
- `storage_upgraded` Boolean that is true if it is cost optimal to include the storage system in the microgrid.
- `discharge_from_storage_series` Array of storage power discharged in every outage modeled.
- `PV_mg_kw` Optimal microgrid PV capacity. Note that the name `PV` can change based on user provided `PV.name`.
- `PV_upgraded` Boolean that is true if it is cost optimal to include the PV system in the microgrid.
- `mg_PV_upgrade_cost` The cost to include the PV system in the microgrid.
- `mg_PV_to_storage_series` Array of PV power sent to the battery in every outage modeled.
- `mg_PV_curtailed_series` Array of PV curtailed in every outage modeled.
- `mg_PV_to_load_series` Array of PV power used to meet load in every outage modeled.
- `Generator_mg_kw` Optimal microgrid Generator capacity. Note that the name `Generator` can change based on user provided `Generator.name`.
- `Generator_upgraded` Boolean that is true if it is cost optimal to include the Generator in the microgrid.
- `mg_Generator_upgrade_cost` The cost to include the Generator system in the microgrid.
- `mg_Generator_to_storage_series` Array of Generator power sent to the battery in every outage modeled.
- `mg_Generator_curtailed_series` Array of Generator curtailed in every outage modeled.
- `mg_Generator_to_load_series` Array of Generator power used to meet load in every outage modeled.
- `mg_Generator_fuel_used_per_outage` Array of Generator fuel used in every outage modeled.
- `generator_fuel_used_per_outage` Array of fuel used in every outage modeled, summed over all Generators.
- `microgrid_upgrade_capital_cost` Total capital cost of including technologies in the microgrid

!!! warn
	The output keys for "Outages" are subject to change.

!!! note 
	`Outage` results only added to results when multiple outages are modeled via the `ElectricUtility.outage_durations` input.

!!! note
	When modeling PV the name of the PV system is used for the output keys to allow for modeling multiple PV systems. The default PV name is `PV`.
	
!!! warn
	The Outage results can be very large when many outages are modeled and can take a long time to generate.
"""
function add_outage_results(m, p, d::Dict)
	# Adds the `Outages` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs`.
	# Only added to results when multiple outages are modeled via the `ElectricUtility.outage_durations` input.

	# TODO with many outages the dispatch arrays are so large that it can take hours to create them
	# (eg. 8760 * 12 hour outages with PV, storage and diesel makes 7*12*8760 = 735,840 values)
	# For now the outage dispatch outputs are not created (commented out below). Perhaps make a new
	# function to optionally get the outage dispatch values so that we don't slow down returning the
	# other results.
	r = Dict{String, Any}()
	r["expected_outage_cost"] = value(m[:ExpectedOutageCost])
	r["max_outage_cost_per_outage_duration"] = value.(m[:dvMaxOutageCost]).data
	r["unserved_load_series"] = value.(m[:dvUnservedLoad]).data
	S = length(p.s.electric_utility.scenarios)
	T = length(p.s.electric_utility.outage_start_time_steps)
	TS = length(p.s.electric_utility.outage_time_steps)
	unserved_load_per_outage = Array{Float64}(undef, S, T)
	for s in 1:S, t in 1:T
		if p.s.electric_utility.outage_durations[s] < TS
			r["unserved_load_series"][s,t,p.s.electric_utility.outage_durations[s]+1:end] .= 0
		end
		unserved_load_per_outage[s, t] = sum(r["unserved_load_series"][s, t, ts] for 
											 ts in 1:p.s.electric_utility.outage_durations[s]) 
		# need to sum over ts in 1:p.s.electric_utility.outage_durations[s] 
		# instead of all ts b/c dvUnservedLoad has unused values in third dimension
	end
	r["unserved_load_per_outage"] = round.(unserved_load_per_outage, digits=2)
	r["mg_storage_upgrade_cost"] = value(m[:dvMGStorageUpgradeCost])
	r["microgrid_upgrade_capital_cost"] = r["mg_storage_upgrade_cost"]
	r["discharge_from_storage_series"] = value.(m[:dvMGDischargeFromStorage]).data

	for t in p.techs.all
		r[t * "_upgraded"] = round(value(m[:binMGTechUsed][t]), digits=0)
	end
	r["storage_upgraded"] = round(value(m[:binMGStorageUsed]), digits=0)

	if !isempty(p.techs.pv)
		for t in p.techs.pv

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(r[t * "_upgraded"])
				r[string(t, "_mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "_mg_kw")] = 0
			end
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)
			r["microgrid_upgrade_capital_cost"] += r[string("mg_", t, "_upgrade_cost")]

			if !isempty(p.s.storage.types.elec)
				PVtoBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_time_steps,
					ts in p.s.electric_utility.outage_time_steps)
			else
				PVtoBatt = []
			end
			r[string("mg_", t, "_to_storage_series")] = round.(value.(PVtoBatt), digits=3)

			PVtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.s.electric_utility.scenarios,
				tz in p.s.electric_utility.outage_start_time_steps,
				ts in p.s.electric_utility.outage_time_steps)
			r[string("mg_", t, "_curtailed_series")] = round.(value.(PVtoCUR), digits=3)

			PVtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts-1] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_time_steps,
					ts in p.s.electric_utility.outage_time_steps
			)
			r[string("mg_", t, "_to_load_series")] = round.(value.(PVtoLoad), digits=3)
		end
	end

	if !isempty(p.techs.gen)
		for t in p.techs.gen

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(r[t * "_upgraded"])
				r[string(t, "_mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "_mg_kw")] = 0
			end

			r[string("mg_", t, "_fuel_used_per_outage")] = value.(m[:dvMGFuelUsed][t, :, :]).data
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)
			r["microgrid_upgrade_capital_cost"] += r[string("mg_", t, "_upgrade_cost")]

			if !isempty(p.s.storage.types.elec)
				GenToBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_time_steps,
					ts in p.s.electric_utility.outage_time_steps)
			else
				GenToBatt = []
			end
			r[string("mg_", t, "_to_storage_series")] = round.(value.(GenToBatt), digits=3)

			GENtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.s.electric_utility.scenarios,
				tz in p.s.electric_utility.outage_start_time_steps,
				ts in p.s.electric_utility.outage_time_steps)
			r[string("mg_", t, "_curtailed_series")] = round.(value.(GENtoCUR), digits=3)

			GENtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts-1] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_time_steps,
					ts in p.s.electric_utility.outage_time_steps
			)
			r[string("mg_", t, "_to_load_series")] = round.(value.(GENtoLoad), digits=3)
		end
		r["generator_fuel_used_per_outage"] = sum(r[string("mg_", t, "_fuel_used_per_outage")] for t in p.techs.gen)
	end
	d["Outages"] = r
end