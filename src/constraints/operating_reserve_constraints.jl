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

function add_operating_reserve_constraints(m, p; _n="")
    # Calculate operating reserves (OR) required 
	# 1. Production going to load from providing_oper_res 
	m[:ProductionToLoadOR] = @expression(m, [t in p.techs.providing_oper_res, ts in p.time_steps_without_grid],
        p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] -
        sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types.elec) -
        m[Symbol("dvCurtail"*_n)][t, ts]
    )
    # 2. Total OR required by requiring_oper_res & Load 
    m[:OpResRequired] = @expression(m, [ts in p.time_steps_without_grid],
        sum(m[:ProductionToLoadOR][t,ts] * p.techs_operating_reserve_req_fraction[t] for t in p.techs.requiring_oper_res)
        + p.s.electric_load.critical_loads_kw[ts] * m[Symbol("dvOffgridLoadServedFraction"*_n)][ts] * p.s.electric_load.operating_reserve_required_fraction
    )
    # 3. Operating reserve provided - battery  
    @constraint(m, [b in p.s.storage.types.elec, ts in p.time_steps_without_grid],
        m[Symbol("dvOpResFromBatt"*_n)][b,ts] <= (m[Symbol("dvStoredEnergy"*_n)][b, ts-1] - p.s.storage.attr[b].soc_min_fraction * m[Symbol("dvStorageEnergy"*_n)][b]) / p.hours_per_time_step 
        - (m[Symbol("dvDischargeFromStorage"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency)
    )
    @constraint(m, [b in p.s.storage.types.elec, ts in p.time_steps_without_grid],
        m[Symbol("dvOpResFromBatt"*_n)][b,ts] <= m[Symbol("dvStoragePower"*_n)][b] - m[Symbol("dvDischargeFromStorage"*_n)][b,ts] / p.s.storage.attr[b].discharge_efficiency
    )
    # 4. Operating reserve provided - techs 
    @constraint(m, [t in p.techs.providing_oper_res, ts in p.time_steps_without_grid],
        m[Symbol("dvOpResFromTechs"*_n)][t,ts] <= (p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvSize"*_n)][t] -
                        m[:ProductionToLoadOR][t,ts]) * (1 - p.techs_operating_reserve_req_fraction[t])
    )
    
    # 5a. Upper bound on dvOpResFromTechs (for generator techs).  Note: will need to add new constraints for each new tech that can provide operating reserves
    @constraint(m, [t in p.techs.gen, ts in p.time_steps_without_grid],
        m[Symbol("dvOpResFromTechs"*_n)][t,ts] <= m[:binGenIsOnInTS][t, ts] * p.max_sizes[t] 
    )
    # 5b. Upper bound on dvOpResFromTechs (for pv techs)
    @constraint(m, [t in p.techs.pv, ts in p.time_steps_without_grid],
        m[Symbol("dvOpResFromTechs"*_n)][t,ts] <= p.max_sizes[t] 
    )

    m[:OpResProvided] = @expression(m, [ts in p.time_steps_without_grid],
        sum(m[Symbol("dvOpResFromTechs"*_n)][t,ts] for t in p.techs.providing_oper_res)
        + sum(m[Symbol("dvOpResFromBatt"*_n)][b,ts] for b in p.s.storage.types.elec)
    )
    # 6. OpRes provided must be greater than OpRes required 
    @constraint(m, [ts in p.time_steps_without_grid],
        m[:OpResProvided][ts] >= m[:OpResRequired][ts]
    )

end
