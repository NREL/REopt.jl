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

function add_electric_vehicle_constraints(m, p, b; _n="")

	# Stored energy must be greater than minimum required for the next trip
	@constraint(m, [ts in p.time_steps],
        m[Symbol("dvStoredEnergy"*_n)][b, ts] 
        >= 
        p.s.storage.attr[b].electric_vehicle.leaving_next_time_step_soc_min[ts] * 
        p.s.storage.attr[b].electric_vehicle.energy_capacity_kwh
    )
	
	# Power to and from EV is zero when it is off-site
	for ts in p.time_steps
        if iszero(p.s.storage.attr[b].electric_vehicle.ev_on_site_series[ts])
            for t in p.techs.elec
                fix(m[Symbol("dvProductionToStorage"*_n)][b, t, ts], 0.0, force=true)
            end
            fix(m[Symbol("dvGridToStorage"*_n)][b, ts], 0.0, force=true)
            fix(m[Symbol("dvDischargeFromStorage"*_n)][b,ts], 0.0, force=true)
        end
    end

    # If not V2G force discharge from EV to zero
    if !p.s.evse.v2g
        for ts in p.time_steps
            fix(m[Symbol("dvDischargeFromStorage"*_n)][b, ts], 0.0, force=true)
        end
    end
end

function add_ev_supply_equipment_constraints(m, p; _n="")

    # Create binary dV for which EVSE the EV is hooked up to
    # TODO EV cannot switch EVSE for the duration of the parking event
    @variable(m, binEVtoEVSE[eachindex(p.s.evse.power_rating_kw), p.s.storage.types.ev, ts in p.time_steps], Bin)
    # Each EVSE can only have at most 1 EV at it, so sum across all EVs for each EVSE
    @constraint(m, [se in eachindex(p.s.evse.power_rating_kw), ts in p.time_steps], 
        sum(binEVtoEVSE[se, ev, ts] for ev in p.s.storage.types.ev) <= 1.0
        )
    
    # Each EV can only be hooked up to a charger if it's on-site
    @constraint(m, [se in eachindex(p.s.evse.power_rating_kw), ev in p.s.storage.types.ev, ts in p.time_steps], 
        binEVtoEVSE[se, ev, ts] <= p.s.storage.attr[ev].electric_vehicle.ev_on_site_series[ts]
        )    

	# Charger rating is greater than total charging power to EACH EV individually
	@constraint(m, [b in p.s.storage.types.ev, ts in p.time_steps],
        sum(p.s.evse.power_rating_kw[se] * m[Symbol("binEVtoEVSE"*_n)][se, b, ts] for se in eachindex(p.s.evse.power_rating_kw))
        >=
        sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for t in p.techs.elec) + m[Symbol("dvGridToStorage"*_n)][b, ts]
    )

	# Charger rating is greater than total dicharge power from EACH EV individually, if V2G is enabled
    if p.s.evse.v2g
        @constraint(m, [b in p.s.storage.types.ev, ts in p.time_steps],
            sum(p.s.evse.power_rating_kw[se] * m[Symbol("binEVtoEVSE"*_n)][se, b, ts] for se in eachindex(p.s.evse.power_rating_kw))
            >=
            sum(m[Symbol("dvDischargeFromStorage"*_n)][b, ts])
        )
    end

end