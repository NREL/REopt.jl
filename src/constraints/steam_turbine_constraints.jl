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

function steam_turbine_thermal_input(m, p; _n="")

    # This constraint is already included in storage_constraints.jl if HotThermalStorage and SteamTurbine are considered that also includes dvProductionToStorage["HotThermalStorage"] in LHS
    if isempty(p.s.storage.types.hot)
        @constraint(m, SupplySteamTurbineProductionLimit[t in p.techs.can_supply_steam_turbine, ts in p.time_steps],
                    m[Symbol("dvThermalToSteamTurbine"*_n)][t,ts] <=
                    m[Symbol("dvThermalProduction"*_n)][t,ts]
        )
    end
end

function steam_turbine_production_constraints(m, p; _n="")
    # Constraint Steam Turbine Thermal Production
    @constraint(m, SteamTurbineThermalProductionCon[t in p.techs.steam_turbine, ts in p.time_steps],
                m[Symbol("dvThermalProduction"*_n)][t,ts] == p.s.steam_turbine.thermal_produced_to_thermal_consumed_ratio * sum(m[Symbol("dvThermalToSteamTurbine"*_n)][tst,ts] for tst in p.techs.can_supply_steam_turbine)
                )
    # Constraint Steam Turbine Electric Production
    @constraint(m, SteamTurbineElectricProductionCon[t in p.techs.steam_turbine, ts in p.time_steps],
                m[Symbol("dvRatedProduction"*_n)][t,ts] ==
                p.s.steam_turbine.electric_produced_to_thermal_consumed_ratio * sum(m[Symbol("dvThermalToSteamTurbine"*_n)][tst,ts] for tst in p.techs.can_supply_steam_turbine)
                )
end

function add_steam_turbine_constraints(m, p; _n="")
    steam_turbine_production_constraints(m, p; _n)
    steam_turbine_thermal_input(m, p; _n)

    m[:TotalSteamTurbinePerUnitProdOMCosts] = @expression(m, p.third_party_factor * p.pwf_om *
        sum(p.s.steam_turbine.om_cost_per_kwh * p.hours_per_time_step *
        m[:dvRatedProduction][t, ts] for t in p.techs.steam_turbine, ts in p.time_steps)
    )
end