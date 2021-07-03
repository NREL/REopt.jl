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
function add_electric_utility_results(m::JuMP.AbstractModel, p::AbstractInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_timestep * sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)
    r["year_one_energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)

    GridToLoad = (m[Symbol("dvGridPurchase"*_n)][ts] - sum(m[Symbol("dvGridToStorage"*_n)][b, ts] 
				  for b in p.storage.types) for ts in p.time_steps)
    r["year_one_to_load_series_kw"] = round.(value.(GridToLoad), digits=3)

    GridToBatt = (sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.storage.types) 
				  for ts in p.time_steps)
    r["year_one_to_battery_series_kw"] = round.(value.(GridToBatt), digits=3)

    d["ElectricUtility"] = r
    nothing
end


function add_electric_utility_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()

    Year1UtilityEnergy = p.hours_per_timestep * sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)
    r["energy_supplied_kwh"] = round(value(Year1UtilityEnergy), digits=2)

    if p.storage.size_kw[:elec] > 0
        GridToBatt = @expression(m, [ts in p.time_steps], 
            sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.storage.types) 
		)
        r["to_battery_series_kw"] = round.(value.(GridToBatt), digits=3).data
    else
        GridToBatt = zeros(length(p.time_steps))
    end
    GridToLoad = @expression(m, [ts in p.time_steps], m[Symbol("dvGridPurchase"*_n)][ts] - GridToBatt[ts])
    r["to_load_series_kw"] = round.(value.(GridToLoad), digits=3).data

    d["ElectricUtility"] = r
    nothing
end