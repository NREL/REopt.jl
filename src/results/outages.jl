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
function add_outage_results(m, p, r::Dict)
	# TODO with many outages the dispatch arrays are so large that it can take hours to create them
	# (eg. 8760 * 12 hour outages with PV, storage and diesel makes 7*12*8760 = 735,840 values)
	# For now the outage dispatch outputs are not created (commented out below). Perhaps make a new
	# function to optionally get the outage dispatch values so that we don't slow down returning the
	# other results.
	r["expected_outage_cost"] = value(m[:ExpectedOutageCost])
	r["max_outage_cost_per_outage_duration"] = value.(m[:dvMaxOutageCost]).data
	r["dvUnservedLoad"] = value.(m[:dvUnservedLoad]).data
	S = length(p.s.electric_utility.scenarios)
	T = length(p.s.electric_utility.outage_start_timesteps)
	unserved_load_per_outage = Array{Float64}(undef, S, T)
	for s in 1:S, t in 1:T
		unserved_load_per_outage[s, t] = sum(r["dvUnservedLoad"][s, t, ts] for 
											 ts in 1:p.s.electric_utility.outage_durations[s]) 
	# need the ts in 1:p.s.electric_utility.outage_durations[s] b/c dvUnservedLoad has unused values in third dimension
	end
	r["unserved_load_per_outage"] = round.(unserved_load_per_outage, digits=2)
	r["mg_storage_upgrade_cost"] = value(m[:dvMGStorageUpgradeCost])
	r["dvMGDischargeFromStorage"] = value.(m[:dvMGDischargeFromStorage]).data

	for t in p.techs
		r[t * "_upgraded"] = value(m[:binMGTechUsed][t])
	end
	r["storage_upgraded"] = value(m[:binMGStorageUsed])

	if !isempty(p.pvtechs)
		for t in p.pvtechs

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(round(r[t * "_upgraded"], digits=1))
				r[string(t, "mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "mg_kw")] = 0
			end
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)

			if !isempty(p.s.storage.types)
				PVtoBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_timesteps,
					ts in p.s.electric_utility.outage_timesteps)
			else
				PVtoBatt = []
			end
			r[string("mg", t, "toBatt")] = round.(value.(PVtoBatt), digits=3)

			PVtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.s.electric_utility.scenarios,
				tz in p.s.electric_utility.outage_start_timesteps,
				ts in p.s.electric_utility.outage_timesteps)
			r[string("mg", t, "toCurtail")] = round.(value.(PVtoCUR), digits=3)

			PVtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_timesteps,
					ts in p.s.electric_utility.outage_timesteps
			)
			r[string("mg", t, "toLoad")] = round.(value.(PVtoLoad), digits=3)
		end
	end

	if !isempty(p.gentechs)
		for t in p.gentechs

			# need the following logic b/c can have non-zero mg capacity when not using the capacity
			# due to the constraint for setting the mg capacities equal to the grid connected capacities
			if Bool(round(r[t * "_upgraded"], digits=1))
				r[string(t, "_mg_kw")] = round(value(m[:dvMGsize][t]), digits=4)
			else
				r[string(t, "mg_kw")] = 0
			end

			r[string("mg_", t, "_fuel_used")] = value.(m[:dvMGFuelUsed][t, :, :]).data
			r[string("mg_", t, "_upgrade_cost")] = round(value(m[:dvMGTechUpgradeCost][t]), digits=2)

			if !isempty(p.s.storage.types)
				GenToBatt = (m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_timesteps,
					ts in p.s.electric_utility.outage_timesteps)
			else
				GenToBatt = []
			end
			r[string("mg", t, "toBatt")] = round.(value.(GenToBatt), digits=3)

			GENtoCUR = (m[:dvMGCurtail][t, s, tz, ts] for 
				s in p.s.electric_utility.scenarios,
				tz in p.s.electric_utility.outage_start_timesteps,
				ts in p.s.electric_utility.outage_timesteps)
			r[string("mg", t, "toCurtail")] = round.(value.(GENtoCUR), digits=3)

			GENtoLoad = (
				m[:dvMGRatedProduction][t, s, tz, ts] * p.production_factor[t, tz+ts] 
						* p.levelization_factor[t]
				- m[:dvMGCurtail][t, s, tz, ts]
				- m[:dvMGProductionToStorage][t, s, tz, ts] for 
					s in p.s.electric_utility.scenarios,
					tz in p.s.electric_utility.outage_start_timesteps,
					ts in p.s.electric_utility.outage_timesteps
			)
			r[string("mg", t, "toLoad")] = round.(value.(GENtoLoad), digits=3)
		end
	end
end