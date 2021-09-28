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

function add_boiler_tech_constraints(m, p; _n="")
    m[:TotalFuelCosts] += @expression(m,
        sum(m[:dvFuelUsage]["ExistingBoiler", ts] * p.s.existing_boiler.fuel_cost_series[ts] for ts in p.time_steps)
    )
    
    # Constraint (1e): Total Fuel burn for Boiler
    @constraint(m, [t in p.techs.boiler, ts in p.time_steps],
        m[:dvFuelUsage][t,ts] == p.hours_per_timestep * (
            m[Symbol("dvThermalProduction"*_n)][t,ts] / p.boiler_efficiency[t]
        )  # TODO removed p.production_factor[t,ts] * b/c all 1's for boiler; do we need it?
    )

    # Constraint (4f)-1: (Hot) Thermal production sent to storage must be less than technology's rated production
    # if !isempty(p.steam_techs)
    #     @constraint(m, [b in p.HotTES, t in p.techs.boiler, ts in p.time_steps],
    #         m[:dvProductionToStorage][b,t,ts] + m[:dvThermalToSteamTurbine][t,ts] <=
    #         p.production_factor[t,ts] * m[Symbol("dvThermalProduction"*_n)][t,ts]
    #     )
    # else
        # @constraint(m, [b in p.HotTES, t in p.techs.boiler, ts in p.time_steps],
        #     m[:dvProductionToStorage][b,t,ts] <= p.production_factor[t,ts] * m[Symbol("dvThermalProduction"*_n)][t,ts]
        # )
    # end

    # Constraint (7_heating_prod_size): Production limit based on size for boiler
    @constraint(m, [t in p.techs.boiler, ts in p.time_steps],
        m[Symbol("dvThermalProduction"*_n)][t,ts] <= m[Symbol("dvSize"*_n)][t]
    )
end