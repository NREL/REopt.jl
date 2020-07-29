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
function add_storage_size_constraints(m, p, b)
    # TODO add formal types for storage (i.e. "b")
    # Constraint (4a): initial state of charge
	@constraint(m,
        m[:dvStoredEnergy][b, 0] == p.storage.soc_init_pct[b] * m[:dvStorageEnergy][b]
    )

	# Constraint (4b)-1: Lower bound on Storage Energy Capacity
	@constraint(m,
        m[:dvStorageEnergy][b] >= p.storage.min_kwh[b]
    )

	# Constraint (4b)-2: Upper bound on Storage Energy Capacity
	@constraint(m,
        m[:dvStorageEnergy][b] <= p.storage.max_kwh[b]
    )

	# Constraint (4c)-1: Lower bound on Storage Power Capacity
	@constraint(m,
        m[:dvStoragePower][b] >= p.storage.min_kw[b]
    )

	# Constraint (4c)-2: Upper bound on Storage Power Capacity
	@constraint(m,
        m[:dvStoragePower][b] <= p.storage.max_kw[b]
    )
end


function add_storage_dispatch_constraints(m, p, b)
				
	# Constraint (4g): state-of-charge for electrical storage - with grid
	@constraint(m, [ts in p.time_steps_with_grid],
        m[:dvStoredEnergy][b, ts] == m[:dvStoredEnergy][b, ts-1] + p.hours_per_timestep * (  
            sum(p.storage.charge_efficiency[b] * m[:dvProductionToStorage][b, t, ts] for t in p.elec_techs) 
            + p.storage.grid_charge_efficiency * m[:dvGridToStorage][b, ts] 
            - m[:dvDischargeFromStorage][b,ts] / p.storage.discharge_efficiency[b]
        )
	)

	# Constraint (4h): state-of-charge for electrical storage - no grid
	@constraint(m, [ts in p.time_steps_without_grid],
        m[:dvStoredEnergy][b, ts] == m[:dvStoredEnergy][b, ts-1] + p.hours_per_timestep * (  
            sum(p.storage.charge_efficiency[b] * m[:dvProductionToStorage][b,t,ts] for t in p.elec_techs) 
            - m[:dvDischargeFromStorage][b, ts] / p.storage.discharge_efficiency[b]
        )
    )

	# Constraint (4j): Minimum state of charge
	@constraint(m, [ts in p.time_steps],
        m[:dvStoredEnergy][b, ts] >= p.storage.soc_min_pct[b] * m[:dvStorageEnergy][b]
    )

	# Constraint (4i)-1: Dispatch to electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[:dvStoragePower][b] >= 
            sum(m[:dvProductionToStorage][b, t, ts] for t in p.elec_techs) + m[:dvGridToStorage][b, ts]
    )
	
	#Constraint (4j): Dispatch from storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps],
        m[:dvStoragePower][b] >= m[:dvDischargeFromStorage][b, ts]
    )
	
	#Constraint (4k)-alt: Dispatch to and from electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps_with_grid],
        m[:dvStoragePower][b] >= m[:dvDischargeFromStorage][b, ts] + 
            sum(m[:dvProductionToStorage][b, t, ts] for t in p.elec_techs) + m[:dvGridToStorage][b, ts]
    )

	#Constraint (4l)-alt: Dispatch from electrical storage is no greater than power capacity
	@constraint(m, [ts in p.time_steps_without_grid],
        m[:dvStoragePower][b] >= m[:dvDischargeFromStorage][b,ts] + 
            sum(m[:dvProductionToStorage][b, t, ts] for t in p.elec_techs)
    )
					
	#Constraint (4n): State of charge upper bound is storage system size
	@constraint(m, [ts in p.time_steps],
        m[:dvStoredEnergy][b,ts] <= m[:dvStorageEnergy][b]
    )
    
    for b in setdiff(p.storage.types, p.storage.can_grid_charge)
        for ts in p.time_steps_with_grid
            fix(m[:dvGridToStorage][b, ts], 0.0, force=true)
        end
	end
end


function add_storage_sum_constraints(m, p)

	##Constraint (8c): Grid-to-storage no greater than grid purchases 
	@constraint(m, [ts in p.time_steps_with_grid],
        m[:dvGridPurchase][ts] >= sum(m[:dvGridToStorage][b, ts] for b in p.storage.types)
    )

	##Constraint (8d): Storage export no greater than discharge from Storage
	@constraint(m, [ts in p.time_steps_with_grid],
        sum(m[:dvDischargeFromStorage][b,ts] for b in p.storage.types)  >= 
            sum(m[:dvStorageExport][b, u, ts] for b in p.storage.types, u in p.storage.export_bins)
    )
end